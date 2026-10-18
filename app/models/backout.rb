class Backout
  def self.call(employee, note: nil)
    bookings = upcoming(employee)
    if bookings.one?
      release(bookings.first, note: note)
    elsif bookings.many?
      Question.open_choice(employee, bookings.map { |assignment| assignment.call_slot.call }, needs_review: note.present?)
    end
  end

  def self.release_from(employee, call, note: nil)
    assignment = employee.assignments.current.joins(:call_slot).find_by(call_slots: { call_id: call.id })
    release(assignment, note: note) if assignment
  end

  # Crew asked to leave. The desk's own release does not come through here, and does not text anyone.
  def self.release(assignment, note: nil)
    assignment.update!(
      confirmation: "declined",
      needs_review: true,
      note: note.presence || assignment.note
    )
    assignment.release!
    Messaging::Deliver.new.call(employee: assignment.employee, body: CallText.removed(assignment.call_slot.call))
    Boss.warn(assignment)
    assignment.call_slot.fill_slot&.fill_process&.advance
  end

  def self.upcoming(employee, now: Time.current)
    employee.assignments.current
      .includes(call_slot: { call: [ :location, { show: { client: :venue } } ] })
      .select { |assignment| assignment.call_slot.call.ends_at > now }
      .sort_by { |assignment| [ assignment.call_slot.call.starts_at, assignment.id ] }
  end
end
