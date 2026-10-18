class Skill < ApplicationRecord
  belongs_to :skill_category
  has_many :employee_skills, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { value.strip.presence }

  validates :name, :sort_order, presence: true
  validates :name, uniqueness: { scope: :skill_category_id, case_sensitive: false }

  before_validation :append_sort_order, on: :create

  scope :for_venue, ->(venue) { joins(:skill_category).where(skill_categories: { venue_id: venue.id }) }

  def venue_id
    skill_category&.venue_id
  end

  def labeled_name
    "#{skill_category.name} — #{name}"
  end

  private
    def append_sort_order
      return if sort_order.present? || skill_category.blank?

      self.sort_order = (skill_category.skills.maximum(:sort_order) || 0) + 1
    end
end
