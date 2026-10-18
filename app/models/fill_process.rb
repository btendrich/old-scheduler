class FillProcess < ApplicationRecord
  STATUSES = %w[pending filling needs_more_names finished].freeze
  MODES = %w[normal emergency].freeze
  RECHECK_AFTER = 5.minutes

  belongs_to :call
  has_many :slots, class_name: "FillSlot", dependent: :destroy
  has_many :call_slots, through: :slots
  has_many :candidates, class_name: "FillCandidate", dependent: :destroy
  has_many :events, class_name: "FillEvent", dependent: :destroy
  has_many :questions, dependent: :nullify

  validates :offer_timeout_minutes, :step_size, :step_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :mode, inclusion: { in: MODES }
  validate :custom_window_has_both_ends

  scope :for_venue, ->(venue) { joins(call: { show: :client }).where(clients: { venue_id: venue.id }) }

  def start!
    return unless status == "pending"

    transaction do
      update!(status: "filling", started_at: Time.current)
      advance
    end
  end

  def emergency?
    mode == "emergency"
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
      ResumeFillJob.set(wait_until: next_window_open).perform_later(id)
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
      ResumeFillJob.set(wait: RECHECK_AFTER).perform_later(id)
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

  def open_owned_slots
    slots.includes(call_slot: :current_assignment).map(&:call_slot)
      .select { |slot| slot.current_assignment.nil? }
      .sort_by { |slot| [ slot.sort_order, slot.id ] }
  end

  private
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
      EmergencyStepJob.set(wait_until: at).perform_later(id)
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

      assignment = slot.assignments.create!(
        employee: candidate.employee,
        source: "automatic",
        confirmation: "confirmed_by_reply",
        note: candidate.note,
        needs_review: candidate.note.present?,
        fill_process: self
      )
      assignment.send_booking_text
      candidate.update!(state: "booked")
      record("booked", candidate.employee, slot.position_label.name)
      close_out_if_full
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
      record("texted", candidate.employee, "Offer sent")
      true
    end

    def decision(candidate)
      employee = candidate.employee
      return :pass if asked_by_another_process?(employee)

      case CallAvailability.new(employee, call).status
      when :on_this_call, :declined then :pass
      when :time_conflict, :waiting_on_another_text then :later
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
        Question.open.find_by(employee_id: candidate.employee_id, fill_process_id: id)&.close!(reason: "filled")
        tell_filled(candidate.employee)
        candidate.update!(state: "passed")
      end
      candidates.where(state: %w[parked timed_out]).find_each do |candidate|
        tell_filled(candidate.employee)
        candidate.update!(state: "passed")
      end
      update!(status: "finished")
    end

    def record(kind, employee, detail)
      events.create!(kind: kind, employee: employee, detail: detail)
    end

    def custom_window_has_both_ends
      return unless custom_window?
      return if window_start.present? && window_end.present?

      errors.add(:window_start, "and end are both required")
    end
end
