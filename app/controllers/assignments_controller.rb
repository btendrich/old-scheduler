class AssignmentsController < ApplicationController
  def new
    @slot = venue_slot
    return if on_fill_redirect || filled_slot_redirect

    prepare_form
  end

  def create
    @slot = venue_slot
    return if on_fill_redirect

    current = @slot.current_assignment
    if current && !ActiveModel::Type::Boolean.new.cast(params[:replace])
      return if filled_slot_redirect
    end
    if current && current.employee_id.to_s == create_params[:employee_id].to_s
      redirect_to @slot.call
      return
    end
    if current && !current.editable_name?
      redirect_to @slot.call, alert: "Cancel the text before changing who is on this slot."
      return
    end

    Assignment.transaction do
      if current
        # Never asked — drop the pencil. A cancel or decline keeps its own history.
        current.destroy!
        @slot.association(:current_assignment).reset
      end
      @assignment = @slot.assignments.new(create_params)
      @assignment.source = "manual"
      @assignment.save!
      @assignment.ask_or_confirm unless @assignment.confirmation == "unconfirmed"
      @slot.fill_slot&.fill_process&.advance
    end
    redirect_to @slot.call
  rescue ActiveRecord::RecordInvalid
    prepare_form
    render :new, status: :unprocessable_entity
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
    assignment.dismiss_questions
    assignment.record_audit("released")
    assignment.call_slot.fill_slot&.fill_process&.advance
    redirect_to assignment.call_slot.call
  end

  def ask
    assignment = venue_assignment
    assignment.ask_or_confirm if assignment.editable_name?
    redirect_to assignment.call_slot.call
  end

  def cancel
    assignment = venue_assignment
    assignment.cancel_text! if !assignment.released_at && !assignment.editable_name?
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

    def on_fill_redirect
      return false unless @slot.fill_slot

      redirect_to @slot.call, alert: "That slot is on a fill."
      true
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
