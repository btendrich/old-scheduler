class TemplateEntry < ApplicationRecord
  belongs_to :template_list
  belongs_to :employee

  def venue
    template_list&.venue
  end

  validates :position, presence: true
  validates :employee_id, uniqueness: { scope: :template_list_id }
end
