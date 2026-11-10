class PositionLabelsController < ApplicationController
  def create
    label = venue.position_labels.new(name_param)
    label.save
    redirect_to setup_path, alert: label.errors.full_messages.to_sentence.presence
  end

  def update
    label = venue.position_labels.find(params[:id])
    label.update(name_param)
    redirect_to setup_path, alert: label.errors.full_messages.to_sentence.presence
  end

  def destroy
    label = venue.position_labels.find(params[:id])
    label.destroy
    redirect_to setup_path, alert: label.errors.full_messages.to_sentence.presence
  end

  private
    def name_param
      params.require(:position_label).permit(:name)
    end
end
