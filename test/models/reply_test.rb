require "test_helper"

class ReplyTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup { travel_to Time.utc(2026, 10, 17, 16, 0, 0) }

  test "YES confirms the open question and sends the booking text once" do
    assignment = book(employees(:alex))
    Question.open_manual_confirmation(assignment)

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")
    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assignment.reload
    assert_equal "confirmed_by_reply", assignment.confirmation
    assert assignment.booking_text_sent_at
    assert_nil Question.open.find_by(employee: employees(:alex))
    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "You're confirmed%").count
    assert_no_match(/\bFOH\b/, employees(:alex).messages.where("body LIKE ?", "You're confirmed%").pick(:body))
  end

  test "YES with extra words confirms, stores the note, and flags review" do
    assignment = book(employees(:alex))
    Question.open_manual_confirmation(assignment)

    Messaging::Receive.new.call(employee: employees(:alex), body: "yes, bring a wrench")

    assignment.reload
    assert_equal "confirmed_by_reply", assignment.confirmation
    assert_equal "bring a wrench", assignment.note
    assert assignment.needs_review
  end

  test "NO to a confirmation takes them off that call only" do
    assignment = book(employees(:alex))
    Question.open_manual_confirmation(assignment)
    other = book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 19, 13, 0, 0))

    Messaging::Receive.new.call(employee: employees(:alex), body: "NO sorry")

    assert assignment.reload.released_at
    assert_equal "declined", assignment.confirmation
    assert_equal "sorry", assignment.note
    assert assignment.needs_review
    assert_nil other.reload.released_at
    assert_match "You're off Saturday Night, Sun 10/18 9:00 AM", employees(:alex).messages.last.body
    assert_nil Question.open.find_by(employee: employees(:alex))
  end

  test "any other reply stays on the thread and leaves the question open" do
    assignment = book(employees(:alex))
    Question.open_manual_confirmation(assignment)

    Messaging::Receive.new.call(employee: employees(:alex), body: "hello")

    assert_equal "unconfirmed", assignment.reload.confirmation
    assert Question.open.find_by(employee: employees(:alex))
    assert_equal "hello", employees(:alex).messages.order(:sent_at, :id).last.body
  end

  test "a second question is refused while one is open" do
    assignment = book(employees(:alex))
    Question.open_manual_confirmation(assignment)
    sent = employees(:alex).messages.count

    assert_nil Question.open_fill_offer(employee: employees(:alex), call: calls(:load_in))
    assert_equal sent, employees(:alex).messages.count
  end

  test "a fill YES books the first open slot" do
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "confirmed_by_desk"
    )
    Question.open_fill_offer(employee: employees(:alex), call: calls(:load_in))

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    booked = call_slots(:foh_slot).reload.current_assignment
    assert_equal employees(:alex), booked.employee
    assert_equal "automatic", booked.source
    assert_equal "confirmed_by_reply", booked.confirmation
    assert booked.booking_text_sent_at
    assert_nil Question.open.find_by(employee: employees(:alex))
  end

  test "a fill YES on a full call is told it is filled" do
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "confirmed_by_desk"
    )
    call_slots(:foh_slot).assignments.create!(
      employee: employees(:casey), source: "manual", confirmation: "confirmed_by_desk"
    )
    Question.open_fill_offer(employee: employees(:alex), call: calls(:load_in))

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_nil employees(:alex).assignments.current.first
    assert_equal "Saturday Night is filled.", employees(:alex).messages.last.body
    assert_nil Question.open.find_by(employee: employees(:alex))
  end

  test "a fill NO declines the call without taking a slot" do
    Question.open_fill_offer(employee: employees(:alex), call: calls(:load_in))

    Messaging::Receive.new.call(employee: employees(:alex), body: "NO")

    assert_empty employees(:alex).assignments
    row = CallAvailability.new(employees(:alex), calls(:load_in))
    assert_equal :declined, row.status
    assert row.placeable?
  end

  test "an open question shows as waiting, after a decline and a time conflict" do
    Question.open_fill_offer(employee: employees(:casey), call: calls(:load_in))
    assert_equal :waiting_on_another_text, CallAvailability.new(employees(:casey), calls(:load_in)).status

    declined = book(employees(:alex), confirmation: "declined")
    declined.release!
    Question.open_fill_offer(employee: employees(:alex), call: later_call)
    assert_equal :declined, CallAvailability.new(employees(:alex), calls(:load_in)).status

    overlapping = book_on_new_call(employees(:blair), starts_at: calls(:load_in).starts_at + 1.hour)
    Question.open_fill_offer(employee: employees(:blair), call: later_call)
    assert_equal :time_conflict, CallAvailability.new(employees(:blair), calls(:load_in)).status
    assert overlapping.persisted?
  end

  test "the picker uses the same waiting and declined flags" do
    Question.open_fill_offer(employee: employees(:alex), call: calls(:load_in))
    Question.open_fill_offer(employee: employees(:blair), call: calls(:load_in))
    Messaging::Receive.new.call(employee: employees(:blair), body: "NO")

    rows = CallAvailability.build_all(venues(:one).employees.ordered, calls(:load_in))

    assert_equal :waiting_on_another_text, rows[0].status
    assert_equal :declined, rows[1].status
  end

  test "a later NO with one upcoming call takes them off it" do
    assignment = book(employees(:alex))
    past = book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 16, 13, 0, 0), ends_at: Time.utc(2026, 10, 16, 20, 0, 0))

    Messaging::Receive.new.call(employee: employees(:alex), body: "NO")

    assert assignment.reload.released_at
    assert_nil past.reload.released_at
    assert_match "You're off", employees(:alex).messages.last.body
  end

  test "a later NO with nothing upcoming is only logged" do
    Messaging::Receive.new.call(employee: employees(:casey), body: "NO")

    assert_equal [ "NO" ], employees(:casey).messages.pluck(:body)
  end

  test "a later NO with several calls asks for a number and waits" do
    first = book(employees(:alex))
    second = book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 20, 13, 0, 0))

    Messaging::Receive.new.call(employee: employees(:alex), body: "NO sorry")

    question = Question.open.find_by!(employee: employees(:alex))
    assert_equal "choice", question.kind
    assert question.needs_review
    assert_nil first.reload.released_at
    assert_nil second.reload.released_at
    assert_match "1. Saturday Night", employees(:alex).messages.last.body
    assert_match "\n2. ", employees(:alex).messages.last.body

    Messaging::Receive.new.call(employee: employees(:alex), body: "hello")
    assert_nil first.reload.released_at
    assert Question.open.find_by(employee: employees(:alex))

    Messaging::Receive.new.call(employee: employees(:alex), body: "2 thanks")

    assert_nil first.reload.released_at
    assert second.reload.released_at
    assert_equal "thanks", second.note
    assert second.needs_review
    assert_nil Question.open.find_by(employee: employees(:alex))
  end

  test "a YES with no open question does not book or confirm anyone" do
    assignment = book(employees(:alex))

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_equal "unconfirmed", assignment.reload.confirmation
    assert_nil assignment.booking_text_sent_at
  end

  private
    def book(employee, confirmation: "unconfirmed")
      call_slots(:deck_slot).assignments.create!(
        employee: employee, source: "manual", confirmation: confirmation
      )
    end

    def book_on_new_call(employee, starts_at:, ends_at: nil)
      call = shows(:saturday).calls.create!(
        location: locations(:main),
        call_type: call_types(:show_call),
        starts_at: starts_at,
        ends_at: ends_at || (starts_at + 8.hours)
      )
      call.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
        employee: employee, source: "manual", confirmation: "unconfirmed"
      )
    end

    def later_call
      @later_call ||= shows(:saturday).calls.create!(
        location: locations(:main),
        call_type: call_types(:show_call),
        starts_at: Time.utc(2026, 10, 21, 13, 0, 0),
        ends_at: Time.utc(2026, 10, 21, 22, 0, 0)
      )
    end
end
