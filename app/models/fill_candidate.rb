class FillCandidate < ApplicationRecord
  STATES = %w[pending asked parked declined passed booked timed_out].freeze

  belongs_to :fill_process, touch: true
  belongs_to :employee

  validates :position, presence: true
  validates :state, inclusion: { in: STATES }
  validates :employee_id, uniqueness: { scope: :fill_process_id }

  def venue
    fill_process&.venue
  end

  scope :ordered, -> { order(:position, :id) }

  def move_higher
    swap_with(predecessor)
  end

  def move_lower
    swap_with(successor)
  end

  private
    def predecessor
      return unless state == "pending"

      fill_process.candidates.where(state: "pending", position: ...position).order(position: :desc).first
    end

    def successor
      return unless state == "pending"

      fill_process.candidates.where(state: "pending", position: (position + 1)..).order(:position, :id).first
    end

    def swap_with(other)
      return if other.blank?

      transaction do
        mine = position
        update!(position: other.position)
        other.update!(position: mine)
      end
    end
end
