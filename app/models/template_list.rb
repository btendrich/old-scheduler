class TemplateList < ApplicationRecord
  belongs_to :venue
  has_many :entries, -> { order(:position, :id) }, class_name: "TemplateEntry", dependent: :destroy, inverse_of: :template_list

  normalizes :name, with: ->(value) { value.strip.presence }

  validates :name, presence: true

  scope :ordered, -> { order(:name, :id) }

  def add_employee(employee)
    return if entries.exists?(employee: employee)

    entries.create!(employee: employee, position: (entries.maximum(:position) || 0) + 1)
  end
end
