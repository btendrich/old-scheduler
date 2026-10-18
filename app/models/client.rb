class Client < ApplicationRecord
  belongs_to :venue
  has_many :shows, dependent: :destroy

  normalizes :name, with: ->(value) { value.strip.presence }

  validates :name, presence: true
end
