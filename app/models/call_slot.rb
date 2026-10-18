class CallSlot < ApplicationRecord
  belongs_to :call
  belongs_to :position_label
  has_many :assignments, dependent: :destroy
  has_one :fill_slot, dependent: :destroy
  has_one :current_assignment, -> { where(released_at: nil) }, class_name: "Assignment"

  validates :sort_order, presence: true
  validate :label_shares_the_call_venue

  scope :for_venue, ->(venue) { joins(call: { show: :client }).where(clients: { venue_id: venue.id }) }

  before_validation :append_sort_order, on: :create

  private
    def append_sort_order
      return if sort_order.present? || call.blank?

      self.sort_order = (call.call_slots.maximum(:sort_order) || 0) + 1
    end

    def label_shares_the_call_venue
      return if call.blank? || position_label.blank?
      return if position_label.venue_id == call.venue_id

      errors.add(:position_label, "is from another venue")
    end
end
