class DeliverWhenOpenJob < ApplicationJob
  def perform(assignment_id)
    assignment = Assignment.find_by(id: assignment_id)
    return if assignment.nil? || assignment.released_at.present?
    return unless assignment.confirmation == "unconfirmed"
    return if Question.unresolved.exists?(assignment_id: assignment.id)

    venue = assignment.call_slot.call.venue
    unless venue.send_window_open?
      self.class.set(wait_until: venue.next_send_window_open).perform_later(assignment.id)
      return
    end

    Question.open_manual_confirmation(assignment)
  end
end
