class QuestionOption < ApplicationRecord
  belongs_to :question
  belongs_to :call

  validates :position, presence: true, uniqueness: { scope: :question_id }
end
