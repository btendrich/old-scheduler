class FillSlot < ApplicationRecord
  belongs_to :fill_process, touch: true
  belongs_to :call_slot

  def venue
    fill_process&.venue || call_slot&.venue
  end

  validates :call_slot_id, uniqueness: true
  validate :slot_is_on_the_process_call
  validate :partner_is_free_for_package

  private
    def slot_is_on_the_process_call
      return if fill_process.blank? || call_slot.blank?
      return if call_slot.call_id == fill_process.call_id

      errors.add(:call_slot, "is on another call")
    end

    def partner_is_free_for_package
      return if call_slot.blank?

      call_slot.reset_link_associations!
      partner = call_slot.partner_slot
      return if partner.blank?

      errors.add(:call_slot, "partner is already on a fill") if partner.fill_slot.present?
      errors.add(:call_slot, "partner is already filled") if partner.current_assignment.present?
    end
end
