class PositionLabel < ApplicationRecord
  belongs_to :venue
  has_many :call_slots, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.strip.presence }

  validates :name, presence: true
  validates :name, uniqueness: { scope: :venue_id, case_sensitive: false }
end
