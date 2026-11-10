class Question < ApplicationRecord
  KINDS = %w[manual_confirmation fill_offer choice evening_reminder].freeze
  CLOSE_REASONS = %w[yes no choice desk timeout filled passed].freeze

  belongs_to :employee
  belongs_to :call, optional: true, touch: true
  belongs_to :assignment, optional: true
  belongs_to :fill_process, optional: true
  has_many :options, -> { order(:position) }, class_name: "QuestionOption", dependent: :destroy, inverse_of: :question

  validates :kind, inclusion: { in: KINDS }
  validates :close_reason, inclusion: { in: CLOSE_REASONS }, allow_nil: true
  validates :position, presence: true, numericality: { only_integer: true }
  validates :employee_id, uniqueness: {
    conditions: -> { where(closed_at: nil).where.not(opened_at: nil) },
    message: "already has a question waiting for a reply"
  }, if: -> { closed_at.nil? && opened_at.present? }
  validate :kind_has_its_target

  # Asked means the text is out. Queued means it is waiting for that text to be sent.
  scope :unresolved, -> { where(closed_at: nil) }
  scope :asked, -> { unresolved.where.not(opened_at: nil) }
  scope :queued, -> { unresolved.where(opened_at: nil) }
  scope :open, -> { asked }

  def self.open_manual_confirmation(assignment)
    existing = unresolved.find_by(assignment_id: assignment.id)
    return existing if existing
    return unless assignment.confirmation == "unconfirmed" && assignment.released_at.nil?

    kept(place(
      assignment.employee,
      kind: "manual_confirmation",
      call: assignment.call_slot.call,
      assignment: assignment
    ))
  end

  def self.open_fill_offer(employee:, call:, process: nil)
    existing = unresolved.find_by(employee_id: employee.id, call_id: call.id, kind: "fill_offer")
    return existing if existing

    kept(place(employee, kind: "fill_offer", call: call, fill_process: process))
  end

  # The numbered list is the open question. Nothing is released until they pick.
  def self.open_choice(employee, calls, needs_review: false)
    return if calls.empty?
    return if unresolved.exists?(employee_id: employee.id, kind: "choice")

    kept(place(employee, kind: "choice", needs_review: needs_review) { |question|
      calls.each_with_index do |call, index|
        question.options.create!(call: call, position: index + 1)
      end
    })
  end

  def self.open_evening_reminder(assignment)
    existing = unresolved.find_by(assignment_id: assignment.id, kind: "evening_reminder")
    return existing if existing
    return if assignment.released_at.present?

    kept(place(
      assignment.employee,
      kind: "evening_reminder",
      call: assignment.call_slot.call,
      assignment: assignment
    ))
  end

  # One text is out at a time. Anything else waits, and a follow-on restates the current question.
  def self.place(employee, **attrs)
    employee.with_lock do
      question = create!(attrs.merge(employee: employee, opened_at: nil, position: next_position(employee)))
      yield question if block_given?
      if question.elapsed? && asked.exists?(employee_id: employee.id)
        question.pass!
      elsif asked.exists?(employee_id: employee.id)
        nudge(employee)
      elsif next_queued(employee) == question
        question.ask_or_wait
      end
      question
    end
  end

  def self.kept(question)
    question&.closed_at.nil? ? question : nil
  end

  def self.ask_next(employee)
    employee.with_lock do
      return if asked.exists?(employee_id: employee.id)

      question = next_queued(employee)
      while question&.elapsed?
        question.pass!
        question = next_queued(employee)
      end
      question&.ask_or_wait
    end
  end

  def self.clear_elapsed(now: Time.current)
    unresolved.includes(:employee, :call, options: :call).find_each do |question|
      next unless question.elapsed?(now)

      current = question.opened_at.present?
      employee = question.employee
      question.pass!
      ask_next(employee) if current
    end
  end

  def self.nudge(employee)
    current = asked.find_by(employee_id: employee.id)
    return unless current

    more = queued.where(employee_id: employee.id).count
    return if more.zero?

    Messaging::Deliver.new.call(employee: employee, body: CallText.queued_notice(current, more))
  end

  def self.next_position(employee)
    (where(employee: employee).maximum(:position) || 0) + 1
  end

  def self.next_queued(employee)
    queued.where(employee_id: employee.id).order(:position, :id).first
  end

  def self.schedule_ask(employee)
    question = next_queued(employee)
    return unless question

    AskQueuedQuestionJob.set(wait_until: question.next_window_at).perform_later(employee.id)
  end

  # The displayed countdown and this job share one deadline. A restart enqueues it again.
  def self.schedule_timeout(question)
    process = question.fill_process
    return unless process
    return if timeout_pending?(question)

    due = question.opened_at + process.offer_timeout_minutes.minutes
    OfferTimeoutJob.set(wait_until: due).perform_later(question.id)
  end

  def self.timeout_pending?(question)
    return false unless queue_ready?

    SolidQueue::Job.where(class_name: "OfferTimeoutJob", finished_at: nil).any? do |job|
      Array(job.arguments["arguments"]) == [ question.id ]
    end
  end

  def self.reschedule_open_timeouts
    open.where(kind: "fill_offer").includes(:fill_process).find_each do |question|
      schedule_timeout(question)
    end
  end

  def self.queue_ready?
    SolidQueue::Job.connection.verify!
    SolidQueue::Job.table_exists?
  rescue ActiveRecord::ActiveRecordError, PG::Error
    false
  end

  def venue
    employee&.venue || call&.venue
  end

  def label
    case kind
    when "manual_confirmation" then "Confirming #{call.show.name}"
    when "fill_offer" then "Offered #{call.show.name}"
    when "evening_reminder" then "Reminder for #{call.show.name}"
    else "Picking a call to leave"
    end
  end

  def reminder_status
    return unless kind == "evening_reminder"

    if closed_at.nil? && opened_at.nil?
      "Reminder queued"
    elsif closed_at.nil?
      "Reminder sent"
    elsif close_reason == "yes"
      "Reminder: confirmed"
    elsif close_reason == "no"
      "Reminder: can't make it"
    else
      "Reminder: no reply"
    end
  end

  def answer(body)
    parsed = Answer.parse(body)
    transaction do
      if kind == "choice"
        answer_choice(parsed)
      else
        answer_yes_no(parsed)
      end
    end
  end

  def close!(reason:)
    return if closed_at.present?

    was_current = opened_at.present?
    update!(closed_at: Time.current, close_reason: reason)
    Question.ask_next(employee) if was_current
  end

  # The call is over, so the question is dropped without a reply and without a "you're off" text.
  def pass!
    return if closed_at.present?

    release_fill_hold
    update!(closed_at: Time.current, close_reason: "passed")
  end

  def elapsed?(now = Time.current)
    calls = related_calls
    return false if calls.empty?

    calls.all? { |item| item.ends_at <= now }
  end

  def ask_or_wait
    if waits_for_window? && !window_open?
      Question.schedule_ask(employee)
      return
    end

    ask!
  end

  def ask!
    update!(opened_at: Time.current)
    Messaging::Deliver.new.call(employee: employee, body: CallText.body_for(self))
    case kind
    when "fill_offer" then Question.schedule_timeout(self)
    when "evening_reminder" then ReminderTimeoutJob.set(wait: 2.hours).perform_later(id)
    end
  end

  def next_window_at
    if fill_process
      fill_process.next_window_open
    else
      call.venue.next_send_window_open
    end
  end

  def timeout!
    return if closed_at.present?

    case kind
    when "fill_offer"
      process = fill_process
      close!(reason: "timeout")
      process&.receive_timeout(employee)
    when "evening_reminder"
      close!(reason: "timeout")
    end
  end

  private
    def waits_for_window?
      kind.in?(%w[manual_confirmation fill_offer])
    end

    def window_open?
      if fill_process
        fill_process.window_open?
      else
        call.venue.send_window_open?
      end
    end

    def related_calls
      case kind
      when "choice" then options.map(&:call)
      else [ call ].compact
      end
    end

    def release_fill_hold
      return unless kind == "fill_offer" && fill_process

      fill_process.candidates.find_by(employee_id: employee_id, state: "asked")&.update!(state: "passed")
    end

    def answer_yes_no(parsed)
      if parsed.yes?
        if kind == "fill_offer" && fill_process
          close!(reason: "yes")
          fill_process.receive_yes(employee, parsed.note)
        else
          accept_yes(parsed.note)
          close!(reason: "yes")
        end
      elsif parsed.no?
        if kind.in?(%w[manual_confirmation evening_reminder]) && assignment&.released_at.nil?
          Backout.release(assignment, note: parsed.note)
        end
        process = fill_process if kind == "fill_offer"
        close!(reason: "no")
        process&.receive_no(employee)
      end
    end

    def accept_yes(note)
      case kind
      when "manual_confirmation" then confirm_manual(note)
      when "evening_reminder" then confirm_reminder(note)
      else book_open_slot(note)
      end
    end

    def confirm_manual(note)
      assignment.update!(
        confirmation: "confirmed_by_reply",
        note: note.presence || assignment.note,
        needs_review: note.present? || assignment.needs_review
      )
      partner = assignment.ensure_package_partner!(
        confirmation: "confirmed_by_reply",
        note: note.presence || assignment.note,
        needs_review: note.present? || assignment.needs_review
      )
      also = partner ? [ partner.call_slot.call ] : []
      assignment.send_booking_text(also: also)
      detail = if partner
        "#{assignment.call_slot.label_name} + #{partner.call_slot.label_name}"
      else
        assignment.call_slot.label_name
      end
      assignment.record_audit("booked", actor: employee, detail: detail)
      partner&.record_audit("booked", actor: employee, detail: "#{partner.call_slot.label_name} · package")
    end

    def confirm_reminder(note)
      became = assignment.confirmation == "unconfirmed"
      if became
        assignment.update!(
          confirmation: "confirmed_by_reply",
          note: note.presence || assignment.note,
          needs_review: note.present? || assignment.needs_review
        )
      elsif note.present?
        assignment.update!(note: note, needs_review: true)
      end
      assignment.send_booking_text
      assignment.record_audit("booked", actor: employee, detail: assignment.call_slot.label_name) if became
    end

    # Offers with no fill process book the first open slot, or say the call is filled.
    def book_open_slot(note)
      return if employee.assignments.current.joins(:call_slot).exists?(call_slots: { call_id: call_id })

      slot = call.call_slots.includes(:current_assignment).detect { |item| item.current_assignment.nil? }
      if slot.nil?
        Messaging::Deliver.new.call(employee: employee, body: CallText.filled(call))
        return
      end

      booked = slot.assignments.create!(
        employee: employee,
        source: "automatic",
        confirmation: "confirmed_by_reply",
        note: note,
        needs_review: note.present?
      )
      booked.send_booking_text
      booked.record_audit("booked", actor: employee, detail: slot.label_name)
    end

    def answer_choice(parsed)
      return unless parsed.number?

      option = options.find_by(position: parsed.number)
      return unless option

      Backout.release_from(employee, option.call, note: parsed.note)
      close!(reason: "choice")
    end

    def kind_has_its_target
      return if kind.blank?

      errors.add(:call, "can't be blank") if kind.in?(%w[manual_confirmation fill_offer evening_reminder]) && call_id.blank?
      errors.add(:assignment, "can't be blank") if kind.in?(%w[manual_confirmation evening_reminder]) && assignment_id.blank?
    end
end
