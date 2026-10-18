class EveningReminder
  def self.call(venue, now: Time.current)
    zone = Time.find_zone(venue.time_zone)
    today = now.in_time_zone(zone).to_date
    return if venue.reminder_sent_on == today

    tomorrow = today + 1
    due = Assignment.current.for_venue(venue)
      .includes(call_slot: { call: { show: { client: :venue } } }, employee: [])
      .select { |assignment| assignment.call_slot.call.starts_at.in_time_zone(zone).to_date == tomorrow }
      .sort_by { |assignment| [ assignment.call_slot.call.starts_at, assignment.id ] }

    due.each { |assignment| Question.open_evening_reminder(assignment) }
    venue.update!(reminder_sent_on: today)
  end
end
