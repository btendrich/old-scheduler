class TemplateList < ApplicationRecord
  belongs_to :venue
  has_many :entries, -> { order(:position, :id) }, class_name: "TemplateEntry", dependent: :destroy, inverse_of: :template_list

  normalizes :name, with: ->(value) { value.strip.presence }

  validates :name, presence: true

  scope :ordered, -> { order(:name, :id) }

  before_create :become_the_default_when_first
  after_destroy :pass_the_default_on

  # One list per venue is the one a call opens on.
  def make_default!
    transaction do
      venue.template_lists.where(default: true).where.not(id: id).update_all(default: false)
      update!(default: true)
    end
  end

  def add_employee(employee)
    return if entries.exists?(employee: employee)

    entries.create!(employee: employee, position: (entries.maximum(:position) || 0) + 1)
  end

  private
    def become_the_default_when_first
      self.default = true unless venue.template_lists.exists?
    end

    def pass_the_default_on
      return unless default

      venue.template_lists.ordered.first&.update!(default: true)
    end
end
