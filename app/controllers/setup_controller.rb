class SetupController < ApplicationController
  def show
    @locations = venue.locations.order(:name)
    @call_types = venue.call_types.order(:name)
    @position_labels = venue.position_labels.order(:name)
    @bosses = venue.bosses.order(:id)
  end

  def update
    hour, minute = params[:reminder_time].to_s.split(":").map(&:to_i)
    # Store the clock time as UTC so the venue zone does not shift it onto the dummy date.
    if venue.update(reminder_time: Time.utc(2000, 1, 1, hour, minute))
      venue.schedule_next_reminder
      redirect_to setup_path
    else
      redirect_to setup_path, alert: venue.errors.full_messages.to_sentence
    end
  end
end
