class OfferTimeoutJob < ApplicationJob
  def perform(question_id)
    Question.find_by(id: question_id)&.timeout!
  end
end
