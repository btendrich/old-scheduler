class CallSlotsController < ApplicationController
  before_action :set_call, only: [ :create, :reorder ]

  def create
    label = label_from(call_slot_params[:position_label_id])
    count.times { @call.call_slots.create!(position_label: label) }
    redirect_to @call
  end

  def update
    slot = CallSlot.for_venue(venue).find(params[:id])
    slot.update!(position_label: label_from(params.dig(:call_slot, :position_label_id)))
    redirect_to slot.call
  end

  def destroy
    slot = CallSlot.for_venue(venue).find(params[:id])
    call = slot.call
    unless slot.removable?
      redirect_to call, alert: "That slot can't be removed while someone has been asked, is confirmed, or it is on a fill."
      return
    end

    slot.destroy!
    compact_sort_orders(call)
    redirect_to call
  end

  def reorder
    saved = ListOrder.apply(@call.call_slots, params[:ids], :sort_order)
    compact_sort_orders(@call) if saved
    head saved ? :no_content : :unprocessable_entity
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

    def label_from(raw)
      return if raw.blank?

      venue.position_labels.find(raw)
    end

    def compact_sort_orders(call)
      call.call_slots.reload.each_with_index do |slot, index|
        slot.update_column(:sort_order, index + 1) if slot.sort_order != index + 1
      end
    end
end
