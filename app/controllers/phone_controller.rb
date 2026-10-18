class PhoneController < ApplicationController
  def show
    if Messaging.live?
      render :offline
      return
    end

    @employees = venue.employees.by_recent_message.to_a
    ActiveRecord::Associations::Preloader.new(records: @employees, associations: :open_question).call
    @employee = if params[:employee_id]
      venue.employees.find(params[:employee_id])
    else
      @employees.first
    end
    @messages = @employee ? @employee.messages.chronological : Message.none
  end

  def reply
    employee = venue.employees.find(params[:employee_id])
    if Messaging.live?
      redirect_to phone_path, alert: "This desk is sending real texts."
      return
    end

    Messaging::Receive.new.call(employee: employee, body: params[:body].to_s)
    redirect_to phone_employee_path(employee)
  rescue ActiveRecord::RecordInvalid
    redirect_to phone_employee_path(employee), alert: "Write a reply first."
  end

  def timeout
    employee = venue.employees.find(params[:employee_id])
    question = Question.open.find_by(employee_id: employee.id, kind: "fill_offer")
    OfferTimeoutJob.perform_now(question.id) if question
    redirect_to phone_employee_path(employee)
  end

  def reminder
    if Messaging.live?
      redirect_to phone_path, alert: "This desk is sending real texts."
      return
    end

    venue.update!(next_reminder_at: Time.current)
    EveningReminderJob.perform_now(venue.id)
    redirect_to phone_path
  end

  def emergency_step
    employee = venue.employees.find(params[:employee_id])
    question = Question.open.find_by(employee_id: employee.id, kind: "fill_offer")
    question.fill_process.run_emergency_step! if question&.fill_process&.emergency?
    redirect_to phone_employee_path(employee)
  end
end
