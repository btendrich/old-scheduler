class AssignmentsController < ApplicationController
  def new
    @slot = venue_slot
    return if filled_slot_redirect

    prepare_form
  end

  def create
    @slot = venue_slot
    return if filled_slot_redirect

    @assignment = @slot.assignments.new(create_params)
    @assignment.source = "manual"
    if @assignment.save
      @assignment.ask_or_confirm
      @slot.fill_slot&.fill_process&.advance
      redirect_to @slot.call
    else
      prepare_form
      render :new, status: :unprocessable_entity
    end
  end

  def update
    assignment = venue_assignment
    previous = assignment.confirmation
    if assignment.update(update_params)
      assignment.note_desk_confirmation(previous)
      redirect_to assignment.call_slot.call
    else
      redirect_to assignment.call_slot.call, alert: assignment.errors.full_messages.to_sentence
    end
  end

  def release
    assignment = Assignment.for_venue(venue).current.find(params[:id])
    assignment.release!
    assignment.open_question&.close!(reason: "desk")
    assignment.call_slot.fill_slot&.fill_process&.advance
    redirect_to assignment.call_slot.call
  end

  private
    def venue_slot
      CallSlot.for_venue(venue).includes(:position_label, :call).find(params[:call_slot_id])
    end

    def venue_assignment
      Assignment.for_venue(venue).find(params[:id])
    end

    def prepare_form
      @call = @slot.call
      @assignment ||= @slot.assignments.new(source: "manual", confirmation: "unconfirmed")
      @availabilities = CallAvailability.build_all(venue.employees.ordered, @call)
    end

    def filled_slot_redirect
      return false unless @slot.current_assignment

      redirect_to @slot.call, alert: "That slot is filled."
      true
    end

    def create_params
      params.require(:assignment).permit(:employee_id, :confirmation, :note)
    end

    def update_params
      params.require(:assignment).permit(:confirmation, :note)
    end
end
