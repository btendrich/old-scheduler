class SkillCategory < ApplicationRecord
  belongs_to :venue
  has_many :skills, -> { order(:sort_order, :id) }, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.strip.presence }

  validates :name, :sort_order, presence: true
  validates :name, uniqueness: { scope: :venue_id, case_sensitive: false }

  scope :ordered, -> { order(:sort_order, :id) }

  before_validation :append_sort_order, on: :create

  private
    def append_sort_order
      return if sort_order.present? || venue.blank?

      self.sort_order = (venue.skill_categories.maximum(:sort_order) || 0) + 1
    end
end
