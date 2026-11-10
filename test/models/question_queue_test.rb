require "test_helper"

class QuestionQueueTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup { travel_to Time.utc(2026, 10, 17, 16, 0, 0) }

  test "a second manual confirmation waits, then is asked when the first is answered" do
    first = book(employees(:alex))
    first.ask_or_confirm
    second = book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 19, 13, 0, 0))
    second.ask_or_confirm

    assert_equal first.id, employees(:alex).open_question.assignment_id
    assert_nil second.questions.queued.pick(:opened_at)
    assert_match "1 more question waiting", employees(:alex).messages.last.body
    assert_match CallText.confirmation(first.call_slot.call), employees(:alex).messages.last.body
    assert_equal 0, employees(:alex).messages.where("body LIKE ?", "%Mon 10/19%").count

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_equal "confirmed_by_reply", first.reload.confirmation
    assert_equal second.id, employees(:alex).reload.open_question.assignment_id
    assert_match CallText.confirmation(second.call_slot.call), employees(:alex).messages.last.body
  end

  test "a follow-on counts every question added behind the current one" do
    first = book(employees(:alex))
    first.ask_or_confirm
    book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 19, 13, 0, 0)).ask_or_confirm
    book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 20, 13, 0, 0)).ask_or_confirm

    assert_match "There are 2 more questions waiting", employees(:alex).messages.last.body
    assert_match "Reply YES to confirm", employees(:alex).messages.last.body
    assert_equal first.id, employees(:alex).open_question.assignment_id
  end

  test "desk confirmation sends the booking text while another question is open" do
    first = book(employees(:alex))
    first.ask_or_confirm
    second = book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 19, 13, 0, 0), confirmation: "confirmed_by_desk")
    second.ask_or_confirm

    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "You're confirmed%").count
    assert_match "Mon 10/19", employees(:alex).messages.where("body LIKE ?", "You're confirmed%").pick(:body)
    assert_empty second.questions.unresolved
    assert_equal first.id, employees(:alex).open_question.assignment_id
  end

  test "desk confirmation of a queued call sends the booking text and does not ask it later" do
    first = book(employees(:alex))
    first.ask_or_confirm
    second = book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 19, 13, 0, 0))
    second.ask_or_confirm
    second.update!(confirmation: "confirmed_by_desk")
    second.note_desk_confirmation("unconfirmed")

    assert_equal "desk", second.questions.last.close_reason
    assert_match "You're confirmed for", employees(:alex).messages.where("body LIKE ?", "%Mon 10/19%").pick(:body)
    assert_equal first.id, employees(:alex).open_question.assignment_id

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_nil employees(:alex).reload.open_question
    assert_not employees(:alex).messages.exists?(body: CallText.confirmation(second.call_slot.call))
  end

  test "a question for a call that has ended is cleared and the next one is asked" do
    first = book(employees(:alex))
    first.ask_or_confirm
    second = book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 20, 13, 0, 0))
    second.ask_or_confirm

    travel_to Time.utc(2026, 10, 18, 22, 0, 0) do
      Question.clear_elapsed
    end

    assert_equal "passed", first.questions.last.close_reason
    assert_nil first.reload.released_at
    assert_not employees(:alex).messages.exists?([ "body LIKE ?", "You're off%" ])
    assert_equal second.id, employees(:alex).reload.open_question.assignment_id
    assert_match "Tue 10/20", employees(:alex).messages.last.body
  end

  test "a queued question for a call that has ended is not sent" do
    first = book_on_new_call(employees(:alex), starts_at: Time.utc(2026, 10, 20, 13, 0, 0))
    first.ask_or_confirm
    past = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: Time.utc(2026, 10, 16, 13, 0, 0),
      ends_at: Time.utc(2026, 10, 16, 22, 0, 0)
    )
    past_slot = past.call_slots.create!(position_label: position_labels(:deck))
    past_assignment = past_slot.assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )

    assert_nil Question.open_manual_confirmation(past_assignment)
    assert_equal first.id, employees(:alex).open_question.assignment_id
  end

  private
    def book(employee)
      call_slots(:deck_slot).assignments.create!(
        employee: employee, source: "manual", confirmation: "unconfirmed"
      )
    end

    def book_on_new_call(employee, starts_at:, confirmation: "unconfirmed")
      call = shows(:saturday).calls.create!(
        location: locations(:main),
        call_type: call_types(:show_call),
        starts_at: starts_at,
        ends_at: starts_at + 8.hours
      )
      call.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
        employee: employee, source: "manual", confirmation: confirmation
      )
    end
end
