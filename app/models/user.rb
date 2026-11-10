class User < ApplicationRecord
  skip_venue_desk!
  has_secure_password
  belongs_to :venue
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
