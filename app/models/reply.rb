class Reply
  def self.apply(message)
    question = Question.open.find_by(employee_id: message.employee_id)
    if question
      question.answer(message.body)
      return
    end

    parsed = Answer.parse(message.body)
    if parsed.yes? && (process = late_fill(message.employee))
      process.receive_late_yes(message.employee, parsed.note)
    elsif parsed.no?
      Backout.call(message.employee, note: parsed.note)
    end
  end

  def self.late_fill(employee)
    question = Question.where(employee: employee, kind: "fill_offer", close_reason: "timeout").order(closed_at: :desc, id: :desc).first
    return if question.nil? || question.fill_process.nil? || question.fill_process.finished?

    question.fill_process
  end
end
