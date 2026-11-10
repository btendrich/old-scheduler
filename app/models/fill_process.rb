class FillProcess < ApplicationRecord
  STATUSES = %w[pending filling needs_more_names finished].freeze
  MODES = %w[normal emergency].freeze
  RECHECK_AFTER = 5.minutes

  belongs_to :call, touch: true
  has_many :slots, class_name: "FillSlot", dependent: :destroy
  has_many :call_slots, through: :slots
  has_many :candidates, class_name: "FillCandidate", dependent: :destroy
  has_many :events, class_name: "FillEvent", dependent: :destroy
  has_many :questions, dependent: :nullify
  has_many :assignments, dependent: :nullify
  has_many :audit_logs, dependent: :nullify

  validates :offer_timeout_minutes, :step_size, :step_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :mode, inclusion: { in: MODES }
  validates :number, presence: true, uniqueness: { scope: :call_id }
  validate :custom_window_has_both_ends

  before_validation :assign_number, on: :create
  after_create :record_created

  scope :for_venue, ->(venue) { joins(call: { show: :client }).where(clients: { venue_id: venue.id }) }
  scope :ordered, -> { order(:number, :id) }

  SlotStatus = Data.define(:label, :people, :status)
  OfferStatus = Data.define(:name, :remaining)

  def venue
    call&.venue
  end

  def running?
    status.in?(%w[filling needs_more_names])
  end

  # Shown before Stop when an offer is still unanswered. The offer itself is left alone.
  def stop_warning
    names = candidates.select { |candidate| candidate.state == "asked" }.sort_by { |candidate| [ candidate.position, candidate.id ] }.map { |candidate| candidate.employee.name }
    return if names.empty?

    offer = names.one? ? "that offer" : "those offers"
    verb = names.one? ? "has" : "have"
    "#{names.to_sentence} #{verb} a text out. Stopping does not cancel #{offer}. A YES can still book. Stop this fill?"
  end

  def start!
    return unless status == "pending"

    transaction do
      update!(status: "filling", started_at: Time.current)
      record("started", nil, "Desk started the fill")
      record_audit("started")
      advance
    end
  end

  # Holds the next text. Offers already out keep their timers, and a YES still books.
  def stop!
    return unless running?

    transaction do
      update!(status: "pending", next_step_at: nil)
      record("paused", nil, "Desk paused the fill")
      record_audit("paused")
    end
  end

  def emergency?
    mode == "emergency"
  end

  # One row per owned slot. A normal fill pairs each open slot with the offer covering it.
  def slot_statuses(now: Time.current)
    offers = offers_out(now)
    cursor = 0
    owned_call_slots.map do |slot|
      assignment = slot.current_assignment
      people = if assignment
        [ OfferStatus.new(assignment.employee.name, nil) ]
      elsif emergency?
        offers
      else
        person = offers[cursor]
        cursor += 1
        person ? [ person ] : []
      end
      SlotStatus.new(slot.label_name, people, line_status(assignment, people))
    end
  end

  # A queued step no-ops until next_step_at, so running one early does not also fire the old timer.
  def emergency_step
    return unless emergency?
    return unless status.in?(%w[filling needs_more_names])
    return if next_step_at.present? && next_step_at > Time.current

    close_out_if_full
    return if finished? || open_owned_slots.empty?

    unless window_open?
      schedule_step(at: next_window_open, detail: "Send window is closed")
      return
    end

    sent = 0
    deferred = false
    candidates.where(state: "pending").ordered.each do |candidate|
      break if sent >= step_size

      case decision(candidate)
      when :ask
        sent += 1 if ask(candidate)
      when :pass
        candidate.update!(state: "passed")
        record("skipped", candidate.employee, "Not asking again")
      when :later
        deferred = true
      end
    end

    return if finished?

    if candidates.where(state: "pending").any? || deferred
      detail = sent.zero? ? "Nobody free to text this step" : "Next step in #{step_minutes} minutes"
      schedule_step(at: step_minutes.minutes.from_now, detail: detail, needs_names: sent.zero?)
    elsif open_owned_slots.any?
      schedule_step(at: RECHECK_AFTER.from_now, detail: "Waiting for another name", needs_names: true)
    end
  end

  def run_emergency_step!
    return unless emergency? && status.in?(%w[filling needs_more_names])

    update!(next_step_at: Time.current)
    emergency_step
  end

  def advance
    return unless status.in?(%w[filling needs_more_names])
    return emergency_step if emergency?

    close_out_if_full
    return if finished? || open_owned_slots.empty?

    unless window_open?
      update!(status: "filling")
      record("waiting", nil, "Send window is closed")
      enqueue_once(ResumeFillJob, wait_until: next_window_open)
      return
    end

    claim_parked
    close_out_if_full
    return if finished? || open_owned_slots.empty?

    needed = open_owned_slots.size - candidates.where(state: "asked").count
    asked_now = 0
    deferred = false
    candidates.where(state: "pending").ordered.each do |candidate|
      break if asked_now >= needed

      case decision(candidate)
      when :ask
        asked_now += 1 if ask(candidate)
      when :pass
        candidate.update!(state: "passed")
        record("skipped", candidate.employee, "Not asking again")
      when :later
        deferred = true
      end
    end

    return if finished?

    still_short = open_owned_slots.size > candidates.where(state: "asked").count
    if still_short && (deferred || candidates.where(state: "pending").none?)
      update!(status: "needs_more_names")
      record("needs_more_names", nil, "Waiting for another name")
      enqueue_once(ResumeFillJob, wait: RECHECK_AFTER)
    else
      update!(status: "filling")
    end
  end

  def add_employee(employee)
    return if candidates.exists?(employee: employee)

    candidate = candidates.create!(employee: employee, position: (candidates.maximum(:position) || 0) + 1, state: "pending")
    advance if status.in?(%w[filling needs_more_names])
    candidate
  end

  def add_with_skill(skill, minimum_level:)
    call.venue.employees.active.with_skill(skill, minimum_level: minimum_level).each do |employee|
      add_employee(employee)
    end
  end

  def add_template(template)
    template.entries.each { |entry| add_employee(entry.employee) }
  end

  # Open slots join this fill. A fill already sending texts offers the new openings.
  def claim(call_slots)
    transaction do
      call_slots.each { |slot| slots.create!(call_slot: slot) }
      advance if status.in?(%w[filling needs_more_names])
    end
  end

  # Partner calls for linked open slots this fill still needs to fill.
  def package_partner_calls
    open_owned_slots.filter_map { |slot| slot.partner_slot&.call }.uniq.reject { |other| other.id == call_id }
  end

  def receive_yes(employee, note)
    place_yes(employee, note, expected: "asked")
  end

  def receive_late_yes(employee, note)
    place_yes(employee, note, expected: "timed_out")
  end

  def receive_no(employee)
    candidates.find_by(employee: employee)&.update!(state: "declined")
    record("no", employee, "Declined")
    advance unless emergency?
  end

  def receive_timeout(employee)
    candidates.find_by(employee: employee, state: "asked")&.update!(state: "timed_out")
    record("timeout", employee, "Offer timed out")
    advance unless emergency?
  end

  def finished?
    status == "finished"
  end

  def window_open?(at = Time.current)
    venue = call.venue
    if custom_window?
      venue.send_window_open?(at, start_at: window_start, finish_at: window_end)
    else
      venue.send_window_open?(at)
    end
  end

  def next_window_open(from = Time.current)
    venue = call.venue
    if custom_window?
      venue.next_send_window_open(from, start_at: window_start, finish_at: window_end)
    else
      venue.next_send_window_open(from)
    end
  end

  # 1-based on the call. A deleted fill does not reuse its number.
  def label
    "#{number}"
  end

  def slot_tally
    names = owned_call_slots.map(&:label_name)
    names.uniq.map { |name| "#{names.count(name)} x #{name}" }.join(", ")
  end

  def phase
    case status
    when "filling" then "running"
    when "needs_more_names" then "needs_names"
    when "finished" then "complete"
    else started_at.present? ? "paused" : "new"
    end
  end

  def synopsis
    total = owned_call_slots.size
    filled = owned_call_slots.count { |slot| slot.current_assignment }
    waiting = candidates.count { |candidate| candidate.state == "asked" }
    case phase
    when "new" then "Not started"
    when "paused" then "#{filled} of #{total} filled · paused"
    when "needs_names" then "#{filled} of #{total} filled · needs names"
    when "complete" then "#{filled} of #{total} filled"
    else
      wait = waiting.positive? ? "#{waiting} waiting" : nil
      [ "#{filled} of #{total} filled", wait ].compact.join(" · ")
    end
  end

  def open_owned_slots
    slots.includes(call_slot: :current_assignment).map(&:call_slot)
      .select { |slot| slot.current_assignment.nil? }
      .sort_by { |slot| [ slot.sort_order, slot.id ] }
  end

  private
    def owned_call_slots
      slots.map(&:call_slot).sort_by { |slot| [ slot.sort_order, slot.id ] }
    end

    def offers_out(now)
      open_questions = questions.select { |question| question.closed_at.nil? && question.kind == "fill_offer" }
      by_employee = open_questions.index_by(&:employee_id)
      candidates.select { |candidate| candidate.state == "asked" }.sort_by { |candidate| [ candidate.position, candidate.id ] }.filter_map do |candidate|
        question = by_employee[candidate.employee_id]
        next unless question

        OfferStatus.new(candidate.employee.name, time_left(question.opened_at, now))
      end
    end

    def time_left(opened_at, now)
      return "Queued" if opened_at.nil?

      remaining = opened_at + offer_timeout_minutes.minutes - now
      return "Timed out" if remaining <= 0

      minutes = (remaining / 60).ceil
      "#{minutes} #{'min'.pluralize(minutes)}"
    end

    def line_status(assignment, people)
      return assignment_status(assignment) if assignment
      return "Waiting for a reply" if people.any?

      "Open"
    end

    def assignment_status(assignment)
      return "Declined" if assignment.confirmation == "declined"
      return "Waiting for a reply" if assignment.open_question

      assignment.confirmation_label
    end

    def place_yes(employee, note, expected:)
      candidate = candidates.find_by(employee: employee, state: expected)
      return unless candidate

      candidate.update!(note: note.presence || candidate.note)
      if emergency?
        place_emergency_yes(candidate)
        return
      end

      if open_owned_slots.empty?
        tell_filled(employee)
        candidate.update!(state: "passed")
        return
      end

      in_flight = candidates.where(state: "asked").where.not(id: candidate.id).count
      if open_owned_slots.size > in_flight
        book(candidate)
      else
        park(candidate)
      end
    end

    def place_emergency_yes(candidate)
      if open_owned_slots.empty?
        tell_filled(candidate.employee)
        candidate.update!(state: "passed")
      else
        book(candidate)
      end
    end

    def schedule_step(at:, detail:, needs_names: false)
      update!(status: needs_names ? "needs_more_names" : "filling", next_step_at: at)
      record(needs_names ? "needs_more_names" : "waiting", nil, detail)
      enqueue_once(EmergencyStepJob, wait_until: at)
    end

    def claim_parked
      loop do
        break if open_owned_slots.size <= candidates.where(state: "asked").count

        parked = candidates.where(state: "parked").order(:position, :id).first
        break unless parked

        book(parked)
      end
    end

    def book(candidate)
      slot = open_owned_slots.first
      return unless slot

      partner = bookable_partner(candidate.employee, slot.partner_slot)
      assignment = slot.assignments.create!(
        employee: candidate.employee,
        source: "automatic",
        confirmation: "confirmed_by_reply",
        note: candidate.note,
        needs_review: candidate.note.present?,
        fill_process: self
      )
      partner_assignment = book_partner(candidate, partner) if partner
      also = partner_assignment ? [ partner.call ] : []
      send_package_booking(assignment, also: also)
      partner_assignment&.update!(booking_text_sent_at: assignment.booking_text_sent_at)
      candidate.update!(state: "booked")
      detail = partner_assignment ? "#{slot.label_name} + #{partner.label_name}" : slot.label_name
      record("booked", candidate.employee, detail)
      assignment.record_audit("booked", actor: candidate.employee, detail: "#{detail} · fill #{number}")
      partner_assignment&.record_audit("booked", actor: candidate.employee, detail: "#{partner.label_name} · fill #{number} package")
      close_out_if_full
    end

    def bookable_partner(employee, partner)
      return if partner.blank? || partner.current_assignment.present?

      status = CallAvailability.new(employee, partner.call).status
      return if status.in?(%i[on_this_call declined time_conflict])

      partner
    end

    def book_partner(candidate, partner)
      partner.assignments.create!(
        employee: candidate.employee,
        source: "automatic",
        confirmation: "confirmed_by_reply",
        note: candidate.note,
        needs_review: candidate.note.present?,
        fill_process: self
      )
    end

    def send_package_booking(assignment, also:)
      return if assignment.booking_text_sent_at.present? || assignment.released_at.present?

      Messaging::Deliver.new.call(
        employee: assignment.employee,
        body: CallText.booking(assignment.call_slot.call, also: also)
      )
      assignment.update!(booking_text_sent_at: Time.current)
    end

    def park(candidate)
      front = (candidates.minimum(:position) || 1) - 1
      candidate.update!(state: "parked", position: front)
      record("parked", candidate.employee, "Waiting at the front of the list")
    end

    def ask(candidate)
      question = Question.open_fill_offer(employee: candidate.employee, call: call, process: self)
      return false unless question

      candidate.update!(state: "asked")
      detail = question.opened_at.present? ? "Offer sent" : "Offer queued"
      record("texted", candidate.employee, detail)
      true
    end

    def decision(candidate)
      employee = candidate.employee
      return :pass if asked_by_another_process?(employee)

      case CallAvailability.new(employee, call).status
      when :on_this_call, :declined then :pass
      when :time_conflict, :waiting_on_another_text, :waiting_on_this_text then :later
      else :ask
      end
    end

    def asked_by_another_process?(employee)
      Question.where(employee: employee, call_id: call_id, kind: "fill_offer").where.not(fill_process_id: nil).where.not(fill_process_id: id).exists?
    end

    def tell_filled(employee)
      Messaging::Deliver.new.call(employee: employee, body: CallText.filled(call))
      record("filled", employee, "Call is filled")
    end

    def close_out_if_full
      return if open_owned_slots.any?

      candidates.where(state: "asked").find_each do |candidate|
        tell_filled(candidate.employee)
        Question.unresolved.find_by(employee_id: candidate.employee_id, fill_process_id: id)&.close!(reason: "filled")
        candidate.update!(state: "passed")
      end
      candidates.where(state: %w[parked timed_out]).find_each do |candidate|
        tell_filled(candidate.employee)
        candidate.update!(state: "passed")
      end
      update!(status: "finished")
    end

    # A check that finds the same situation again updates the last line instead of
    # adding another copy. Adding a name, or any other kind of line, starts fresh.
    def record(kind, employee, detail)
      last = events.order(created_at: :desc, id: :desc).first
      if last && last.kind == kind && last.employee_id == employee&.id && last.detail == detail
        last.increment!(:times)
        return last
      end

      events.create!(kind: kind, employee: employee, detail: detail)
    end

    def enqueue_once(job, wait: nil, wait_until: nil)
      return if job_pending?(job)

      options = wait_until ? { wait_until: wait_until } : { wait: wait }
      job.set(options).perform_later(id)
    end

    # The job that is running this check is already claimed. It does not count,
    # or the check would never schedule the next one.
    def job_pending?(job)
      if ActiveJob::Base.queue_adapter.is_a?(ActiveJob::QueueAdapters::TestAdapter)
        ActiveJob::Base.queue_adapter.enqueued_jobs.any? { |queued| queued[:job] == job && Array(queued[:args]) == [ id ] }
      elsif queue_ready?
        SolidQueue::Job.where(class_name: job.name, finished_at: nil).any? do |queued|
          next false unless Array(queued.arguments["arguments"]) == [ id ]

          queued.scheduled_execution.present? || queued.ready_execution.present?
        end
      else
        false
      end
    end

    def queue_ready?
      SolidQueue::Job.connection.verify!
      SolidQueue::Job.table_exists?
    rescue ActiveRecord::ActiveRecordError, PG::Error
      false
    end

    def custom_window_has_both_ends
      return unless custom_window?
      return if window_start.present? && window_end.present?

      errors.add(:window_start, "and end are both required")
    end

    def assign_number
      return if number.present? || call.blank?

      self.number = (call.fill_processes.maximum(:number) || 0) + 1
    end

    def record_created
      record("created", nil, "Fill #{number}")
    end

    def record_audit(kind)
      AuditLog.record(kind: kind, subject: self, call: call, fill_process: self, detail: "Fill #{number}")
    end
end
