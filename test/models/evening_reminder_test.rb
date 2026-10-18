require "test_helper"

class EveningReminderTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup { travel_to Time.utc(2026, 10, 17, 22, 0, 0) }

  test "the reminder goes to people on tomorrow's calls and not to anyone else" do
    tomorrow = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    later = later_call(Time.utc(2026, 10, 19, 13, 0, 0)).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "unconfirmed"
    )

    EveningReminder.call(venues(:one))

    assert_equal "evening_reminder", employees(:alex).open_question.kind
    assert_match "Reminder: reply YES to confirm", employees(:alex).messages.last.body
    assert_match "Saturday Night, Sun 10/18 9:00 AM–6:00 PM, Main stage", employees(:alex).messages.last.body
    assert_nil employees(:blair).open_question
    assert_equal tomorrow, employees(:alex).open_question.assignment
    assert_nil later.employee.open_question
  end

  test "a same-day call and a second run do not send another reminder" do
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    EveningReminder.call(venues(:one))

    added = later_call(Time.utc(2026, 10, 18, 18, 0, 0))
    slot = added.assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "confirmed_by_desk"
    )
    EveningReminder.call(venues(:one))

    assert_equal 0, employees(:blair).messages.where("body LIKE ?", "%Reminder:%").count
    assert_nil slot.questions.find_by(kind: "evening_reminder")

    travel_to Time.utc(2026, 10, 18, 22, 0, 0) do
      venues(:one).update!(reminder_sent_on: nil)
      EveningReminder.call(venues(:one))
    end

    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "%Reminder:%").count
  end

  test "someone who already has a question is skipped" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    assignment.ask_or_confirm

    EveningReminder.call(venues(:one))

    assert_equal "manual_confirmation", employees(:alex).open_question.kind
    assert_equal 0, employees(:alex).messages.where("body LIKE ?", "%Reminder:%").count
  end

  test "YES confirms an unconfirmed booking once and does not send the booking text again" do
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    EveningReminder.call(venues(:one))

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES running late")

    assignment = call_slots(:deck_slot).reload.current_assignment
    assert_equal "confirmed_by_reply", assignment.confirmation
    assert_equal "running late", assignment.note
    assert assignment.needs_review
    assert_equal "yes", employees(:alex).questions.last.close_reason
    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "You're confirmed%").count

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "You're confirmed%").count
  end

  test "YES on a booking that was already confirmed does not send another booking text" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk"
    )
    assignment.ask_or_confirm
    EveningReminder.call(venues(:one))

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_equal "confirmed_by_desk", assignment.reload.confirmation
    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "You're confirmed%").count
    assert_equal "Reminder: confirmed", assignment.reminder_question.reminder_status
  end

  test "NO drops that call, warns the bosses, and leaves the other call alone" do
    venues(:one).bosses.create!(mobile: "555-0900")
    venues(:one).bosses.create!(mobile: "555-0901")
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk"
    )
    other = later_call(Time.utc(2026, 10, 19, 13, 0, 0))
    other.assignments.create!(employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk")
    EveningReminder.call(venues(:one))

    Messaging::Receive.new.call(employee: employees(:alex), body: "NO")

    assert_nil call_slots(:deck_slot).reload.current_assignment
    assert_equal employees(:alex), other.reload.current_assignment.employee
    assert_match "You're off Saturday Night, Sun 10/18 9:00 AM", employees(:alex).messages.last.body
    notices = BossNotice.order(:id)
    assert_equal [ "555-0900", "555-0901" ], notices.map(&:mobile)
    assert_equal "Alex can't make Saturday Night, Sun 10/18 9:00 AM, Deck.", notices.first.body
  end

  test "no reply leaves them on the call and does not text the bosses" do
    venues(:one).bosses.create!(mobile: "555-0900")
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    EveningReminder.call(venues(:one))

    ReminderTimeoutJob.perform_now(employees(:alex).open_question.id)

    assert_equal employees(:alex), call_slots(:deck_slot).reload.current_assignment.employee
    assert_equal "timeout", employees(:alex).questions.last.close_reason
    assert_equal "Reminder: no reply", call_slots(:deck_slot).current_assignment.reminder_question.reminder_status
    assert_equal 0, BossNotice.count
  end

  test "a desk release does not text the bosses" do
    venues(:one).bosses.create!(mobile: "555-0900")
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk"
    )

    assignment.release!

    assert_equal 0, BossNotice.count
  end

  test "firing the reminder early does not send a second one when the timer arrives" do
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    venue = venues(:one)
    venue.update!(next_reminder_at: Time.current)
    EveningReminderJob.perform_now(venue.id)
    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "%Reminder:%").count

    travel_to venue.reload.next_reminder_at - 1.hour do
      perform_enqueued_jobs(only: EveningReminderJob)
    end

    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "%Reminder:%").count
  end

  private
    def later_call(starts_at)
      call = shows(:saturday).calls.create!(
        location: locations(:main),
        call_type: call_types(:show_call),
        starts_at: starts_at,
        ends_at: starts_at + 4.hours
      )
      call.call_slots.create!(position_label: position_labels(:deck))
    end
end
