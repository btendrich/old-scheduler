class Assignment < ApplicationRecord
  SOURCES = %w[manual automatic].freeze
  CONFIRMATIONS = %w[unconfirmed confirmed_by_reply confirmed_by_desk declined].freeze
  CONFIRMATION_LABELS = {
    "unconfirmed" => "Unconfirmed",
    "confirmed_by_reply" => "Confirmed by reply",
    "confirmed_by_desk" => "Confirmed by desk",
    "declined" => "Declined"
  }.freeze

  belongs_to :call_slot, touch: true
  belongs_to :employee
  belongs_to :fill_process, optional: true
  has_many :audit_logs, as: :subject, dependent: :nullify
  has_many :questions, dependent: :destroy
  has_many :boss_notices, dependent: :destroy
  has_one :open_question, -> { where(closed_at: nil).where.not(opened_at: nil) }, class_name: "Question"

  normalizes :note, with: ->(value) { value.strip.presence }

  validates :source, inclusion: { in: SOURCES }
  validates :confirmation, inclusion: { in: CONFIRMATIONS }
  validates :call_slot_id, uniqueness: {
    conditions: -> { where(released_at: nil) },
    message: "already has someone"
  }
  validate :employee_belongs_to_the_call_venue
  validate :employee_is_free_for_this_call, on: :create

  scope :current, -> { where(released_at: nil) }
  scope :for_venue, ->(venue) {
    joins(call_slot: { call: { show: :client } }).where(clients: { venue_id: venue.id })
  }

  def self.confirmation_choices
    CONFIRMATION_LABELS.map { |value, label| [ label, value ] }
  end

  def venue
    call_slot&.call&.venue
  end

  def confirmation_label
    CONFIRMATION_LABELS.fetch(confirmation)
  end

  def review_item
    return if released_at

    name = employee.name
    items = []
    items << "#{name} needs review" if needs_review?
    items << "#{name} declined this slot" if confirmation == "declined"
    items << "Waiting on #{name}" if open_question
    items
  end

  # Asked means a text is out or still unanswered. Confirmed is the stronger warning.
  def replacement_warning
    return if released_at

    name = employee.name
    if %w[confirmed_by_reply confirmed_by_desk].include?(confirmation)
      "#{name} is confirmed for this slot. Assign someone else?"
    elsif open_question || booking_text_sent_at
      "#{name} has already been asked about this slot. Assign someone else?"
    end
  end

  def reminder_question
    questions.select { |question| question.kind == "evening_reminder" }.max_by(&:id)
  end

  def source_label
    source == "manual" ? "Manual" : "Automatic"
  end

  def confirmed?
    confirmation.in?(%w[confirmed_by_reply confirmed_by_desk])
  end

  def outcome_detail
    "#{employee.name} · #{call_slot.label_name}"
  end

  def record_audit(kind, actor: :current, detail: nil, fill: fill_process)
    AuditLog.record(
      kind: kind,
      actor: actor,
      subject: self,
      call: call_slot.call,
      fill_process: fill,
      detail: detail || outcome_detail
    )
  end

  # The row stays so a decline on this call can still show in the picker.
  def release!
    update!(released_at: Time.current)
  end

  def cancelled?
    if audit_logs.loaded?
      audit_logs.any? { |log| log.kind == "cancelled" }
    else
      audit_logs.exists?(kind: "cancelled")
    end
  end

  # A name can be swapped until Ask, a confirmation, or a booking text commits the slot.
  def editable_name?
    released_at.nil? && confirmation == "unconfirmed" && booking_text_sent_at.nil? && !pending_question?
  end

  def pending_question?
    questions.any? { |question| question.closed_at.nil? }
  end

  def ask_or_confirm
    if %w[confirmed_by_desk confirmed_by_reply].include?(confirmation)
      ensure_package_partner!(confirmation: confirmation)
      send_booking_text
      record_audit("booked")
    elsif confirmation == "unconfirmed"
      Question.open_manual_confirmation(self)
      record_audit("asked")
    end
  end

  # Partner call on a linked slot that this person can still take.
  def package_partner_calls
    partner = bookable_package_partner
    partner ? [ partner.call ] : []
  end

  # Book or confirm the linked partner slot for the same person.
  def ensure_package_partner!(confirmation: "confirmed_by_reply", note: nil, needs_review: false)
    partner = bookable_package_partner
    return unless partner

    existing = partner.current_assignment
    record = if existing
      return if existing.employee_id != employee_id

      existing.update!(
        confirmation: confirmation,
        note: note.presence || existing.note,
        needs_review: needs_review || existing.needs_review
      )
      existing
    else
      partner.assignments.create!(
        employee: employee,
        source: source,
        confirmation: confirmation,
        note: note,
        needs_review: needs_review,
        fill_process: fill_process
      )
    end
    partner.association(:current_assignment).reset
    record
  end

  # The desk took the ask back. The employee is told they are off, and the bosses are not paged.
  def cancel_text!
    return if released_at

    Messaging::Deliver.new.call(employee: employee, body: CallText.removed(call_slot.call))
    dismiss_questions
    release!
    record_audit("cancelled")
  end

  def note_desk_confirmation(previous)
    return if confirmation == previous

    if %w[confirmed_by_desk confirmed_by_reply].include?(confirmation)
      ensure_package_partner!(confirmation: confirmation, note: note, needs_review: needs_review?)
      send_booking_text
    end
    dismiss_questions
    Question.open_manual_confirmation(self) if confirmation == "unconfirmed"
    record_desk_confirmation_audit(previous)
  end

  # Drop every question about this assignment. Closing the one they were answering asks the next.
  def dismiss_questions
    questions.unresolved.order(Arel.sql("CASE WHEN opened_at IS NULL THEN 0 ELSE 1 END"), :id).each do |question|
      question.close!(reason: "desk")
    end
  end

  # Sent once, the first time they become confirmed. A later reminder YES does not send it again.
  def send_booking_text(also: nil)
    return if booking_text_sent_at.present? || released_at.present?

    also_calls = also.nil? ? package_partner_calls : Array(also)
    Messaging::Deliver.new.call(employee: employee, body: CallText.booking(call_slot.call, also: also_calls))
    sent_at = Time.current
    update!(booking_text_sent_at: sent_at)
    mark_partner_booking_sent!(sent_at)
  end

  private
    def bookable_package_partner
      partner = call_slot.partner_slot
      return if partner.blank?

      existing = partner.current_assignment
      if existing
        return if existing.employee_id != employee_id

        return partner
      end

      status = CallAvailability.new(employee, partner.call).status
      return if status.in?(%i[on_this_call declined time_conflict])

      partner
    end

    def mark_partner_booking_sent!(sent_at)
      partner = call_slot.partner_slot
      return unless partner

      other = partner.current_assignment
      return unless other && other.employee_id == employee_id && other.booking_text_sent_at.nil?

      other.update!(booking_text_sent_at: sent_at)
    end

    def record_desk_confirmation_audit(previous)
      if %w[confirmed_by_desk confirmed_by_reply].include?(confirmation)
        record_audit("booked")
      elsif confirmation == "declined"
        record_audit("declined")
      elsif confirmation == "unconfirmed" && previous != "unconfirmed"
        record_audit("asked")
      end
    end

    def employee_belongs_to_the_call_venue
      return if employee.blank? || call_slot.blank?
      return if employee.venue_id == call_slot.call.venue_id

      errors.add(:employee, "is from another venue")
    end

    def employee_is_free_for_this_call
      return if employee.blank? || call_slot.blank?

      taken = Assignment.current.joins(:call_slot)
        .where(employee_id: employee_id, call_slots: { call_id: call_slot.call_id })
        .where.not(id: id)
      return unless taken.exists?

      errors.add(:employee, "is already on this call")
    end
end
