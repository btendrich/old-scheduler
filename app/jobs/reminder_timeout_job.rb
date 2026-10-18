class ReminderTimeoutJob < ApplicationJob
  def perform(question_id)
    question = Question.find_by(id: question_id)
    question.timeout! if question&.kind == "evening_reminder"
  end
end
