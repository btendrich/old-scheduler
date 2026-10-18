class Boss < ApplicationRecord
  belongs_to :venue

  normalizes :mobile, with: ->(value) { value.strip.presence }

  validates :mobile, presence: true, uniqueness: { scope: :venue_id }

  def self.warn(assignment, gateway: Messaging.gateway)
    venue = assignment.call_slot.call.venue
    body = CallText.boss_warning(assignment)
    venue.bosses.each do |boss|
      BossNotice.create!(
        venue: venue,
        assignment: assignment,
        mobile: boss.mobile,
        body: body,
        sent_at: Time.current
      )
      gateway.deliver(to: boss.mobile, body: body)
    end
  end
end
