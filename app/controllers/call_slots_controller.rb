class CallSlotsController < ApplicationController
  before_action :set_call, only: :create

  def create
    label = venue.position_labels.find_by(id: call_slot_params[:position_label_id])
    if label.nil?
      redirect_to @call, alert: "Choose a position label."
      return
    end

    count.times { @call.call_slots.create!(position_label: label) }
    redirect_to @call
  end

  def destroy
    slot = CallSlot.for_venue(venue).find(params[:id])
    call = slot.call
    slot.destroy!
    redirect_to call
  end

  private
    def set_call
      @call = Call.for_venue(venue).find(params[:call_id])
    end

    def call_slot_params
      params.fetch(:call_slot, {}).permit(:position_label_id)
    end

    def count
      requested = params[:count].to_i
      requested = 1 if requested < 1
      [ requested, 20 ].min
    end
end
