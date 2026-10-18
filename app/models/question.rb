class Question < ApplicationRecord
  KINDS = %w[manual_confirmation fill_offer choice evening_reminder].freeze
  CLOSE_REASONS = %w[yes no choice desk timeout filled].freeze

  belongs_to :employee
  belongs_to :call, optional: true
  belongs_to :assignment, optional: true
  belongs_to :fill_process, optional: true
  has_many :options, -> { order(:position) }, class_name: "QuestionOption", dependent: :destroy, inverse_of: :question

  validates :kind, inclusion: { in: KINDS }
  validates :close_reason, inclusion: { in: CLOSE_REASONS }, allow_nil: true
  validates :opened_at, presence: true
  validates :employee_id, uniqueness: {
    conditions: -> { where(closed_at: nil) },
    message: "already has an open question"
  }
  validate :kind_has_its_target

  scope :open, -> { where(closed_at: nil) }

  def self.open_manual_confirmation(assignment)
    return if open.exists?(employee_id: assignment.employee_id)
    return unless assignment.confirmation == "unconfirmed" && assignment.released_at.nil?

    question = create!(
      employee: assignment.employee,
      kind: "manual_confirmation",
      call: assignment.call_slot.call,
      assignment: assignment,
      opened_at: Time.current
    )
    Messaging::Deliver.new.call(employee: assignment.employee, body: CallText.confirmation(question.call))
    question
  end

  def self.open_fill_offer(employee:, call:, process: nil)
    return if open.exists?(employee_id: employee.id)

    question = create!(
      employee: employee,
      kind: "fill_offer",
      call: call,
      fill_process: process,
      opened_at: Time.current
    )
    body = if process&.emergency?
      CallText.emergency_offer(call, spots: process.open_owned_slots.size)
    else
      CallText.offer(call)
    end
    Messaging::Deliver.new.call(employee: employee, body: body)
    OfferTimeoutJob.set(wait: process.offer_timeout_minutes.minutes).perform_later(question.id) if process
    question
  end

  # The numbered list is the open question. Nothing is released until they pick.
  def self.open_choice(employee, calls, needs_review: false)
    return if open.exists?(employee_id: employee.id)

    transaction do
      question = create!(employee: employee, kind: "choice", needs_review: needs_review, opened_at: Time.current)
      calls.each_with_index do |call, index|
        question.options.create!(call: call, position: index + 1)
      end
      Messaging::Deliver.new.call(employee: employee, body: CallText.choice(calls))
      question
    end
  end

  def self.open_evening_reminder(assignment)
    return if open.exists?(employee_id: assignment.employee_id)
    return if assignment.released_at.present?

    question = create!(
      employee: assignment.employee,
      kind: "evening_reminder",
      call: assignment.call_slot.call,
      assignment: assignment,
      opened_at: Time.current
    )
    Messaging::Deliver.new.call(employee: assignment.employee, body: CallText.reminder(question.call))
    ReminderTimeoutJob.set(wait: 2.hours).perform_later(question.id)
    question
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

    if closed_at.nil?
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
    update!(closed_at: Time.current, close_reason: reason)
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
      assignment.send_booking_text
    end

    def confirm_reminder(note)
      if assignment.confirmation == "unconfirmed"
        assignment.update!(
          confirmation: "confirmed_by_reply",
          note: note.presence || assignment.note,
          needs_review: note.present? || assignment.needs_review
        )
      elsif note.present?
        assignment.update!(note: note, needs_review: true)
      end
      assignment.send_booking_text
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
