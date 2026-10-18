class CallTypesController < ApplicationController
  def create
    call_type = venue.call_types.new(name_param)
    call_type.save
    redirect_to setup_path, alert: call_type.errors.full_messages.to_sentence.presence
  end

  def destroy
    call_type = venue.call_types.find(params[:id])
    call_type.destroy
    redirect_to setup_path, alert: call_type.errors.full_messages.to_sentence.presence
  end

  private
    def name_param
      params.require(:call_type).permit(:name)
    end
end
