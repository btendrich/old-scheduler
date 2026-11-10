class SlotLinksController < ApplicationController
  def create
    slot = venue_slot
    partner = CallSlot.for_venue(venue).find(params[:partner_slot_id])
    slot.link_to!(partner)
    redirect_to slot.call
  rescue ActiveRecord::RecordInvalid => error
    redirect_to slot.call, alert: error.record.errors.full_messages.to_sentence
  end

  def destroy
    slot = venue_slot
    slot.unlink!
    redirect_to slot.call
  end

  private
    def venue_slot
      CallSlot.for_venue(venue).find(params[:call_slot_id])
    end
end
