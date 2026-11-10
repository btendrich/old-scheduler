class Show < ApplicationRecord
  belongs_to :client
  has_many :calls, dependent: :destroy

  normalizes :name, with: ->(value) { value.strip.presence }

  validates :name, presence: true

  scope :for_venue, ->(venue) { joins(:client).where(clients: { venue_id: venue.id }) }

  def venue
    client&.venue
  end

  def venue_id
    client&.venue_id
  end
end
