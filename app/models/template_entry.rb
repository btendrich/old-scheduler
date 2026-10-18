class TemplateEntry < ApplicationRecord
  belongs_to :template_list
  belongs_to :employee

  validates :position, presence: true
  validates :employee_id, uniqueness: { scope: :template_list_id }

  def move_higher
    swap_with(template_list.entries.where(position: ...position).order(position: :desc).first)
  end

  def move_lower
    swap_with(template_list.entries.where(position: (position + 1)..).order(:position, :id).first)
  end

  private
    def swap_with(other)
      return if other.blank?

      transaction do
        mine = position
        update!(position: other.position)
        other.update!(position: mine)
      end
    end
end
