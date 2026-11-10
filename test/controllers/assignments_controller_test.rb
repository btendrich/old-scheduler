require "test_helper"

class AssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the desk assigns a person and the call shows them" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      assignment: {
        employee_id: employees(:alex).id,
        confirmation: "confirmed_by_desk",
        note: " already called ",
        source: "automatic"
      }
    }

    assignment = call_slots(:deck_slot).reload.current_assignment
    assert_redirected_to call_path(calls(:load_in))
    assert_equal "manual", assignment.source
    assert_equal "confirmed_by_desk", assignment.confirmation
    assert_equal "already called", assignment.note
    assert assignment.booking_text_sent_at
    assert_nil employees(:alex).open_question
    assert_match "You're confirmed", employees(:alex).messages.last.body
    assert_no_match(/\bDeck\b/, employees(:alex).messages.last.body)

    follow_redirect!
    assert_match "Alex", response.body
    assert_match "Confirmed by desk", response.body
    assert_match "already called", response.body
    assert_select ".call-banner", text: /1\s+Confirmed/
  end

  test "a confirmed person stays until cancel, which keeps the old row" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk"
    )

    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:blair).id, confirmation: "unconfirmed" }
    }

    assert_redirected_to call_path(calls(:load_in))
    assert_nil assignment.reload.released_at
    assert_equal employees(:alex), call_slots(:deck_slot).reload.current_assignment.employee

    post cancel_assignment_path(assignment)

    assert assignment.reload.released_at
    assert_match "You're off", employees(:alex).messages.last.body
    assert_nil call_slots(:deck_slot).reload.current_assignment

    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:blair).id, confirmation: "unconfirmed" }
    }

    assert_equal employees(:blair), call_slots(:deck_slot).reload.current_assignment.employee
  end

  test "choosing a name assigns them and waits for ask" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:blair).id, confirmation: "unconfirmed" }
    }

    assignment = call_slots(:deck_slot).reload.current_assignment
    assert_equal employees(:blair), assignment.employee
    assert_equal "unconfirmed", assignment.confirmation
    assert_nil assignment.booking_text_sent_at
    assert_nil employees(:blair).open_question
    assert_equal 0, employees(:blair).messages.count

    follow_redirect!
    assert_select "td.slot-commit button[aria-label='Ask Cole, Blair']", text: "Ask"
    assert_select "td.slot-commit .slot-cancel-button", count: 0
    assert_select "button.assign-picker-locked", count: 0
    assert_match "Open", response.body

    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }

    assert_equal employees(:alex), call_slots(:deck_slot).reload.current_assignment.employee
    assert_equal 0, employees(:blair).messages.count
    assert_equal 0, employees(:alex).messages.count
    assert_nil Assignment.find_by(id: assignment.id)
    follow_redirect!
    assert_select "ul.slot-history li", text: /Cole, Blair/, count: 0
  end

  test "ask sends the confirmation and locks the name" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:blair).id, confirmation: "unconfirmed" }
    }
    assignment = call_slots(:deck_slot).reload.current_assignment

    post ask_assignment_path(assignment)

    assert_redirected_to call_path(calls(:load_in))
    assert_equal "manual_confirmation", employees(:blair).reload.open_question.kind
    assert_match "Reply YES", employees(:blair).messages.last.body
    follow_redirect!
    assert_match "Waiting for a reply", response.body
    assert_select "button.assign-picker-locked[disabled]", text: "Cole, Blair"
    assert_select "td.slot-commit button[aria-label='Cancel Cole, Blair'][data-message=?]", "Cancel Cole, Blair for this call? They'll be texted that they're off."
    assert_select "button", text: "Cancel", count: 0
    assert_select "td.slot-commit button", text: "Ask", count: 0

    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }

    assert_redirected_to call_path(calls(:load_in))
    assert_equal "Cancel the text before changing who is on this slot.", flash[:alert]
    assert_equal employees(:blair), call_slots(:deck_slot).reload.current_assignment.employee
  end

  test "cancel texts them off and the name can be changed again" do
    venues(:one).bosses.create!(mobile: "555-0900")
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:blair).id, confirmation: "unconfirmed" }
    }
    assignment = call_slots(:deck_slot).reload.current_assignment
    post ask_assignment_path(assignment)

    post cancel_assignment_path(assignment)

    assert assignment.reload.released_at
    assert_nil employees(:blair).reload.open_question
    assert_match "You're off Saturday Night", employees(:blair).messages.last.body
    assert_equal 0, BossNotice.count
    assert_nil call_slots(:deck_slot).reload.current_assignment
    follow_redirect!
    assert_select "button.assign-picker-locked", count: 0
    assert_select "input[aria-label='Search employees']"
    assert_select "ul.slot-history li", text: /Cole, Blair · Cancelled/
  end

  test "a penciled name can be swapped or the slot removed, and a committed slot cannot" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:blair).id, confirmation: "unconfirmed" }
    }

    delete call_slot_path(call_slots(:deck_slot))

    assert_redirected_to call_path(calls(:load_in))
    assert_nil CallSlot.find_by(id: call_slots(:deck_slot).id)

    post call_slot_assignments_path(call_slots(:foh_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:alex).id, confirmation: "confirmed_by_desk" }
    }
    delete call_slot_path(call_slots(:foh_slot))

    assert_redirected_to call_path(calls(:load_in))
    assert_equal "That slot can't be removed while someone has been asked, is confirmed, or it is on a fill.", flash[:alert]
    assert CallSlot.find_by(id: call_slots(:foh_slot).id)
  end

  test "a slot on a fill cannot be removed" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))

    delete call_slot_path(call_slots(:deck_slot))

    assert_redirected_to call_path(calls(:load_in))
    assert_equal "That slot can't be removed while someone has been asked, is confirmed, or it is on a fill.", flash[:alert]
    assert CallSlot.find_by(id: call_slots(:deck_slot).id)
  end

  test "the picker shows one status and blocks a second slot on this call" do
    other = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: calls(:load_in).starts_at + 1.hour,
      ends_at: calls(:load_in).ends_at + 1.hour
    )
    other.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "unconfirmed"
    )
    declined = call_slots(:deck_slot).assignments.create!(
      employee: employees(:casey), source: "manual", confirmation: "declined"
    )
    declined.release!

    get new_call_slot_assignment_path(call_slots(:foh_slot))

    assert_response :success
    assert_match "Time conflict", response.body
    assert_match "Declined", response.body
    assert_match "Available", response.body
    assert_select "option", text: "Cole, Blair - Time conflict"
    assert_select "option", text: "Ng, Casey (inactive) - Declined"

    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }
    get new_call_slot_assignment_path(call_slots(:foh_slot))

    assert_match "On this call", response.body
    assert_select "option", text: "Rivera, Alex - On this call", count: 0

    post call_slot_assignments_path(call_slots(:foh_slot)), params: {
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }

    assert_response :unprocessable_entity
    assert_match "already on this call", response.body
  end

  test "a slot on a fill shows its person and cannot be reassigned" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "automatic", confirmation: "unconfirmed", fill_process: process
    )

    get call_path(calls(:load_in))

    assert_select "button.assign-picker-locked[disabled]", text: "Rivera, Alex"
    assert_select "input[aria-label='Search employees']"

    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      replace: "1",
      assignment: { employee_id: employees(:blair).id, confirmation: "unconfirmed" }
    }

    assert_redirected_to call_path(calls(:load_in))
    assert_equal employees(:alex), call_slots(:deck_slot).reload.current_assignment.employee
    follow_redirect!
    assert_match "That slot is on a fill.", response.body
  end

  test "a filled slot cannot be assigned again" do
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )

    get new_call_slot_assignment_path(call_slots(:deck_slot))

    assert_redirected_to call_path(calls(:load_in))
    assert_equal "That slot is filled.", flash[:alert]
  end

  test "release reopens the slot and keeps the history" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk"
    )

    patch release_assignment_path(assignment)

    assert_redirected_to call_path(calls(:load_in))
    assert assignment.reload.released_at
    assert_nil call_slots(:deck_slot).reload.current_assignment
    follow_redirect!
    assert_match "Assign", response.body
    assert_select "ul.slot-history li", text: /Rivera, Alex · Confirmed by desk/
  end

  test "marking a booking declined shows a warning and still holds the slot" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )

    patch assignment_path(assignment), params: {
      assignment: { confirmation: "declined", note: "sick" }
    }

    assert_redirected_to call_path(calls(:load_in))
    follow_redirect!
    assert_match "Cannot make it", response.body
    assert_match "sick", response.body
    assert call_slots(:deck_slot).reload.current_assignment
  end

  test "another venue's slot and assignment are not reachable" do
    other_client = venues(:other).clients.create!(name: "Elsewhere")
    other_show = other_client.shows.create!(name: "Night")
    other_call = other_show.calls.create!(
      location: locations(:other_room),
      call_type: call_types(:other_show),
      starts_at: Time.utc(2026, 10, 18, 13, 0, 0),
      ends_at: Time.utc(2026, 10, 18, 22, 0, 0)
    )
    other_slot = other_call.call_slots.create!(position_label: position_labels(:other_deck))
    other_assignment = other_slot.assignments.create!(
      employee: employees(:outsider), source: "manual", confirmation: "unconfirmed"
    )

    get new_call_slot_assignment_path(other_slot)
    assert_response :not_found

    patch release_assignment_path(other_assignment)
    assert_response :not_found
    assert_nil other_assignment.reload.released_at
  end

  test "a person from another venue cannot be booked onto this call" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      assignment: { employee_id: employees(:outsider).id, confirmation: "unconfirmed" }
    }

    assert_response :unprocessable_entity
    assert_match "another venue", response.body
    assert_nil call_slots(:deck_slot).reload.current_assignment
  end

  test "YES confirms an unconfirmed assign and the booking text goes once" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }
    assignment = call_slots(:deck_slot).reload.current_assignment
    post ask_assignment_path(assignment)

    post phone_replies_path(employees(:alex)), params: { body: "YES running late" }

    assignment.reload
    assert_equal "confirmed_by_reply", assignment.confirmation
    assert_equal "running late", assignment.note
    assert assignment.needs_review
    assert assignment.booking_text_sent_at
    assert_nil employees(:alex).reload.open_question
    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "You're confirmed%").count
  end

  test "the desk confirming closes the question without a second booking text" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }
    assignment = call_slots(:deck_slot).reload.current_assignment
    post ask_assignment_path(assignment)

    patch assignment_path(assignment), params: { assignment: { confirmation: "confirmed_by_desk" } }

    assert_nil employees(:alex).reload.open_question
    assert assignment.reload.booking_text_sent_at
    sent = employees(:alex).messages.where("body LIKE ?", "You're confirmed%").count

    patch assignment_path(assignment), params: { assignment: { confirmation: "confirmed_by_desk", note: "still good" } }

    assert_equal sent, employees(:alex).messages.where("body LIKE ?", "You're confirmed%").count
  end

  test "releasing an unconfirmed person drops the question and does not text them off" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }
    assignment = call_slots(:deck_slot).reload.current_assignment
    post ask_assignment_path(assignment)

    patch release_assignment_path(assignment)

    assert assignment.reload.released_at
    assert_nil employees(:alex).reload.open_question
    assert_not employees(:alex).messages.exists?([ "body LIKE ?", "You're off%" ])
  end
end
