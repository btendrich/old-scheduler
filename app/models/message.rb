class Message < ApplicationRecord
  DIRECTIONS = %w[outbound inbound].freeze

  belongs_to :employee

  normalizes :body, :mobile, with: ->(value) { value.strip.presence }

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :body, :mobile, :sent_at, presence: true

  scope :chronological, -> { order(:sent_at, :id) }

  def outbound?
    direction == "outbound"
  end

  def inbound?
    direction == "inbound"
  end
end
