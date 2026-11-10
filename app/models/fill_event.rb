class FillEvent < ApplicationRecord
  skip_venue_desk!
  belongs_to :fill_process
  belongs_to :employee, optional: true

  validates :kind, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  after_create_commit :publish_log
  after_update_commit :publish_log

  private
    def publish_log
      fill_process.events.reset
      Turbo::StreamsChannel.broadcast_replace_to(
        fill_process,
        target: ActionView::RecordIdentifier.dom_id(fill_process, :log),
        partial: "calls/fill_log",
        locals: { process: fill_process }
      )
    end
end
