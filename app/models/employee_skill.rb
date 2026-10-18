class EmployeeSkill < ApplicationRecord
  belongs_to :employee
  belongs_to :skill

  normalizes :note, with: ->(value) { value.strip.presence }

  validates :level, inclusion: { in: 1..5 }
  validates :skill_id, uniqueness: { scope: :employee_id }
  validate :skill_is_from_the_employee_venue

  private
    def skill_is_from_the_employee_venue
      return if employee.blank? || skill.blank?
      return if skill.venue_id == employee.venue_id

      errors.add(:skill, "is from another venue")
    end
end
