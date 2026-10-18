class CalendarsController < ActionController::Base
  def show
    call = Call.find_signed!(params[:id], purpose: :calendar)
    send_data call.to_ics, filename: "#{call.show.name.parameterize}.ics", type: "text/calendar; charset=utf-8", disposition: "inline"
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    head :not_found
  end
end
