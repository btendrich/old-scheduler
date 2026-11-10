class AuditLog < ApplicationRecord
  KINDS = %w[assigned asked cancelled booked released declined backed_out started paused].freeze
  CALL_OUTCOMES = %w[asked booked released cancelled declined backed_out started paused].freeze

  belongs_to :venue
  belongs_to :actor, polymorphic: true, optional: true
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :call, optional: true
  belongs_to :fill_process, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :detail, :actor_name, presence: true

  scope :chronological, -> { order(:created_at, :id) }
  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :outcomes, -> { where(kind: CALL_OUTCOMES) }

  after_create_commit :publish_call_log

  # actor: :current uses the signed-in desk user. Pass an Employee, FillProcess,
  # User, or system: "evening_reminder" / "receive" when no person is on the request.
  def self.record(kind:, detail:, subject: nil, call: nil, fill_process: nil, actor: :current, system: nil)
    actor = Current.user if actor == :current
    call ||= subject_call(subject) || fill_process&.call
    create!(
      venue: call&.venue || actor_venue(actor),
      actor: actor,
      actor_name: actor_label(actor, system),
      system_name: actor.present? ? nil : system.to_s.presence,
      subject: subject,
      subject_name: subject_label(subject),
      call: call,
      fill_process: fill_process,
      kind: kind,
      detail: detail
    )
  end

  def self.actor_label(actor, system)
    case actor
    when User then actor.email_address
    when FillProcess then "Fill #{actor.number}"
    when Employee then actor.name
    else system.to_s.humanize.presence || "System"
    end
  end

  def self.subject_label(subject)
    return unless subject

    subject.try(:name) || subject.try(:label_name) || "#{subject.model_name.human} #{subject.id}"
  end

  def self.subject_call(subject)
    return subject if subject.is_a?(Call)
    return subject.call if subject.respond_to?(:call) && !subject.is_a?(CallSlot)
    return subject.call if subject.is_a?(CallSlot)
    return subject.call_slot.call if subject.respond_to?(:call_slot) && subject.call_slot
  end

  def self.actor_venue(actor)
    actor.try(:venue) || actor.try(:call)&.venue
  end

  private
    def publish_call_log
      return unless call

      Turbo::StreamsChannel.broadcast_replace_to(
        call,
        target: ActionView::RecordIdentifier.dom_id(call, :audit_log),
        partial: "calls/audit_log",
        locals: { call: call }
      )
    end
end
