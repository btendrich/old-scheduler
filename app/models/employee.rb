class Employee < ApplicationRecord
  belongs_to :venue
  has_many :employee_skills, dependent: :destroy
  has_many :skills, through: :employee_skills
  has_many :assignments, dependent: :restrict_with_error
  has_many :messages, dependent: :destroy
  has_many :questions, dependent: :destroy
  has_many :fill_candidates, dependent: :destroy
  has_many :template_entries, dependent: :destroy
  has_one :open_question, -> { where(closed_at: nil) }, class_name: "Question"

  normalizes :preferred_name, :legal_name, :mobile, with: ->(value) { value.strip.presence }
  normalizes :email, with: ->(value) { value.strip.downcase.presence }
  normalizes :notes, with: ->(value) { value.strip.presence }

  validates :preferred_name, :mobile, :sort_order, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  scope :ordered, -> { order(:sort_order, :id) }
  scope :by_recent_message, -> {
    left_joins(:messages)
      .group("employees.id")
      .order(Arel.sql("MAX(messages.sent_at) DESC NULLS LAST, employees.sort_order ASC, employees.id ASC"))
  }
  scope :active, -> { where(active: true) }
  scope :with_skill, ->(skill, minimum_level: 1) {
    joins(:employee_skills)
      .where(employee_skills: { skill_id: skill.id, level: minimum_level.. })
      .order("employees.sort_order ASC, employees.id ASC")
  }

  before_validation :append_sort_order, on: :create

  def self.find_by_mobile(number)
    find_each.detect { |employee| Messaging::Phone.same?(employee.mobile, number) }
  end

  def question_label
    question = open_question
    return "No open question" unless question

    question.needs_review? ? "#{question.label} · Needs review" : question.label
  end

  def move_higher
    swap_with(predecessor)
  end

  def move_lower
    swap_with(successor)
  end

  def skills_in_order
    employee_skills.select(&:persisted?).sort_by { |row| [ row.skill.skill_category.sort_order, row.skill.sort_order, row.id ] }
  end

  private
    def append_sort_order
      return if sort_order.present? || venue.blank?

      self.sort_order = (venue.employees.maximum(:sort_order) || 0) + 1
    end

    def predecessor
      venue.employees.where(sort_order: ...sort_order).order(sort_order: :desc).first
    end

    def successor
      venue.employees.where(sort_order: (sort_order + 1)..).order(:sort_order, :id).first
    end

    def swap_with(other)
      return if other.blank?

      transaction do
        mine = sort_order
        update!(sort_order: other.sort_order)
        other.update!(sort_order: mine)
      end
    end
end
