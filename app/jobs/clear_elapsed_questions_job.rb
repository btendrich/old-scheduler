class ClearElapsedQuestionsJob < ApplicationJob
  def perform
    Question.clear_elapsed
  end
end
