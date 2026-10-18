class BossNotice < ApplicationRecord
  belongs_to :venue
  belongs_to :assignment

  validates :mobile, :body, :sent_at, presence: true
end
