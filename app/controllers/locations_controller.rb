class LocationsController < ApplicationController
  def create
    location = venue.locations.new(name_param)
    location.save
    redirect_to setup_path, alert: location.errors.full_messages.to_sentence.presence
  end

  def update
    location = venue.locations.find(params[:id])
    location.update(name_param)
    redirect_to setup_path, alert: location.errors.full_messages.to_sentence.presence
  end

  def destroy
    location = venue.locations.find(params[:id])
    location.destroy
    redirect_to setup_path, alert: location.errors.full_messages.to_sentence.presence
  end

  private
    def name_param
      params.require(:location).permit(:name)
    end
end
