class AskQueuedQuestionJob < ApplicationJob
  def perform(employee_id)
    employee = Employee.find_by(id: employee_id)
    Question.ask_next(employee) if employee
  end
end
