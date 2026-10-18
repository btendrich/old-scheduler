class MessagesController < ApplicationController
  def create
    employee = venue.employees.find(params[:employee_id])
    Messaging::Deliver.new.call(employee: employee, body: params[:body].to_s)
    redirect_to employee
  rescue ActiveRecord::RecordInvalid
    redirect_to employee, alert: "Write a message first."
  end
end
