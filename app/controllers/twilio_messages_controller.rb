class TwilioMessagesController < ActionController::Base
  skip_forgery_protection

  def create
    unless Messaging::TwilioGateway.valid_signature?(request.original_url, request.request_parameters, request.headers["X-Twilio-Signature"].to_s)
      head :forbidden
      return
    end

    employee = Employee.find_by_mobile(params[:From])
    Messaging::Receive.new.call(employee: employee, body: params[:Body].to_s) if employee
    render xml: "<Response></Response>", content_type: "text/xml"
  rescue ActiveRecord::RecordInvalid
    render xml: "<Response></Response>", content_type: "text/xml"
  end
end
