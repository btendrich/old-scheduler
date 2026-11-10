class QuestionOption < ApplicationRecord
  belongs_to :question
  belongs_to :call

  def venue
    call&.venue
  end

  validates :position, presence: true, uniqueness: { scope: :question_id }
end
