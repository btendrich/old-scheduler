class FillEvent < ApplicationRecord
  belongs_to :fill_process
  belongs_to :employee, optional: true

  validates :kind, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }
end
