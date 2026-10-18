class Assignment < ApplicationRecord
  SOURCES = %w[manual automatic].freeze
  CONFIRMATIONS = %w[unconfirmed confirmed_by_reply confirmed_by_desk declined].freeze
  CONFIRMATION_LABELS = {
    "unconfirmed" => "Unconfirmed",
    "confirmed_by_reply" => "Confirmed by reply",
    "confirmed_by_desk" => "Confirmed by desk",
    "declined" => "Declined"
  }.freeze

  belongs_to :call_slot
  belongs_to :employee
  belongs_to :fill_process, optional: true
  has_many :questions, dependent: :destroy
  has_many :boss_notices, dependent: :destroy
  has_one :open_question, -> { where(closed_at: nil) }, class_name: "Question"

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

  def confirmation_label
    CONFIRMATION_LABELS.fetch(confirmation)
  end

  def reminder_question
    questions.select { |question| question.kind == "evening_reminder" }.max_by(&:id)
  end

  def source_label
    source == "manual" ? "Manual" : "Automatic"
  end

  # The row stays so a decline on this call can still show in the picker.
  def release!
    update!(released_at: Time.current)
  end

  def ask_or_confirm
    if %w[confirmed_by_desk confirmed_by_reply].include?(confirmation)
      send_booking_text
    elsif confirmation == "unconfirmed"
      ask_when_the_window_is_open
    end
  end

  def note_desk_confirmation(previous)
    return if confirmation == previous

    open_question.close!(reason: "desk") if open_question&.assignment_id == id
    if %w[confirmed_by_desk confirmed_by_reply].include?(confirmation)
      send_booking_text
    elsif confirmation == "unconfirmed"
      ask_when_the_window_is_open
    end
  end

  def ask_when_the_window_is_open
    venue = call_slot.call.venue
    if venue.send_window_open?
      Question.open_manual_confirmation(self)
    else
      DeliverWhenOpenJob.set(wait_until: venue.next_send_window_open).perform_later(id)
    end
  end

  # Sent once, the first time they become confirmed. A later reminder YES does not send it again.
  def send_booking_text
    return if booking_text_sent_at.present? || released_at.present?

    Messaging::Deliver.new.call(employee: employee, body: CallText.booking(call_slot.call))
    update!(booking_text_sent_at: Time.current)
  end

  private
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
