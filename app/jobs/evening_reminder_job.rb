class EveningReminderJob < ApplicationJob
  def perform(venue_id)
    venue = Venue.find_by(id: venue_id)
    return unless venue
    return if venue.next_reminder_at.present? && venue.next_reminder_at > Time.current

    EveningReminder.call(venue)
    venue.schedule_next_reminder
  end
end
