class CallSlot < ApplicationRecord
  belongs_to :call, touch: true
  belongs_to :position_label, optional: true
  has_many :assignments, dependent: :destroy
  has_one :fill_slot, dependent: :destroy
  has_one :current_assignment, -> { where(released_at: nil) }, class_name: "Assignment"
  has_one :outbound_link, class_name: "SlotLink", dependent: :destroy
  has_one :inbound_link, class_name: "SlotLink", foreign_key: :partner_slot_id, dependent: :destroy, inverse_of: :partner_slot

  validates :sort_order, presence: true
  validate :label_shares_the_call_venue

  scope :for_venue, ->(venue) { joins(call: { show: :client }).where(clients: { venue_id: venue.id }) }

  before_validation :append_sort_order, on: :create

  def venue
    call&.venue
  end

  def label_name
    position_label&.name || "Unassigned"
  end

  def partner_slot
    outbound_link&.partner_slot || inbound_link&.call_slot
  end

  def linked?
    partner_slot.present?
  end

  def link_to!(other)
    SlotLink.create!(call_slot: self, partner_slot: other).tap do
      reset_link_associations!(other)
    end
  end

  def unlink!
    other = partner_slot
    (outbound_link || inbound_link)&.destroy!
    reset_link_associations!(other)
  end

  def reset_link_associations!(other = nil)
    association(:outbound_link).reset
    association(:inbound_link).reset
    return unless other

    other.association(:outbound_link).reset
    other.association(:inbound_link).reset
  end

  # Partner is on an unfinished fill, so this side is reserved for that package.
  def package_held?
    return false if current_assignment.present? || fill_slot.present?

    partner = partner_slot
    return false if partner.blank? || partner.current_assignment.present? || partner.fill_slot.blank?

    process = partner.fill_slot.fill_process
    process.present? && !process.finished?
  end

  # An empty slot, or a name that has not been asked or confirmed, can leave the call.
  def removable?
    return false if fill_slot
    return false if package_held?

    current = current_assignment
    current.nil? || current.editable_name?
  end

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
