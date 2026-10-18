class FillSlot < ApplicationRecord
  belongs_to :fill_process
  belongs_to :call_slot

  validates :call_slot_id, uniqueness: true
  validate :slot_is_on_the_process_call

  private
    def slot_is_on_the_process_call
      return if fill_process.blank? || call_slot.blank?
      return if call_slot.call_id == fill_process.call_id

      errors.add(:call_slot, "is on another call")
    end
end
