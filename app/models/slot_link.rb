class SlotLink < ApplicationRecord
  belongs_to :call_slot, touch: true
  belongs_to :partner_slot, class_name: "CallSlot", touch: true

  validate :slots_differ
  validate :same_show
  validate :neither_already_linked, on: :create

  def venue
    call_slot&.venue
  end

  def other_slot(slot)
    slot.id == call_slot_id ? partner_slot : call_slot
  end

  private
    def slots_differ
      return if call_slot_id.blank? || partner_slot_id.blank?
      return if call_slot_id != partner_slot_id

      errors.add(:partner_slot, "can't be the same slot")
    end

    def same_show
      return if call_slot.blank? || partner_slot.blank?
      return if call_slot.call.show_id == partner_slot.call.show_id

      errors.add(:partner_slot, "must be on the same show")
    end

    def neither_already_linked
      return if call_slot.blank? || partner_slot.blank?

      call_slot.reset_link_associations!
      partner_slot.reset_link_associations!
      errors.add(:call_slot, "is already linked") if call_slot.partner_slot.present?
      errors.add(:partner_slot, "is already linked") if partner_slot.partner_slot.present?
    end
end
