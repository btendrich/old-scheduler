require "test_helper"

class CallsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup { sign_in_as users(:one) }

  test "a call shows in the venue clock" do
    get call_path(calls(:load_in))

    assert_response :success
    assert_match "Sun 10/18 9:00 AM", response.body
    assert_match "Sun 10/18 6:00 PM", response.body
    assert_match "Acme Touring", response.body
    assert_match "Saturday Night", response.body
    assert_select ".call-banner", text: /2\s+Slots/
    assert_select ".call-banner", text: /0\s+Confirmed/
    assert_select ".call-banner", text: /Awaiting Reply/
    assert_select ".call-banner", text: /Assigned to Auto-Fills/
    assert_match "Nothing to review", response.body
    assert_match "Deck", response.body
    assert_match "FOH", response.body
    assert_match "Create a fill", response.body
    assert_no_match "Start a fill", response.body
    assert_select "button", text: "Add slot"
    assert_select "button", text: "Clear selection"
    assert_select "textarea[aria-label='Call audit log']"
    assert_desk_live
  end

  test "the call audit log shows a booking and hides the fill walk" do
    travel_to Time.utc(2026, 10, 17, 16, 0, 0)

    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }
    assignment = call_slots(:deck_slot).reload.current_assignment
    post ask_assignment_path(assignment)

    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:foh_slot))
    process.add_employee(employees(:blair))
    process.start!
    Messaging::Receive.new.call(employee: employees(:blair), body: "YES")

    get call_path(calls(:load_in))

    log = css_select("textarea[aria-label='Call audit log']").text
    assert_match "Asked", log
    assert_match "Booked", log
    assert_match employees(:blair).name, log
    assert_match "fill #{process.number}", log
    assert_no_match "Assigned", log
    assert_no_match "Offer sent", log
    assert_select "textarea[aria-label='Fill log']", text: /Offer sent|Offer queued/
  end

  test "a new call starts with unassigned slots" do
    post show_calls_path(shows(:saturday)), params: {
      slot_count: 2,
      call: {
        location_id: locations(:main).id,
        call_type_id: call_types(:show_call).id,
        starts_at: "2026-10-24T09:00",
        ends_at: "2026-10-24T17:00"
      }
    }

    call = shows(:saturday).calls.order(:created_at).last
    assert_redirected_to call
    assert_equal [ nil, nil ], call.call_slots.order(:sort_order).pluck(:position_label_id)
    follow_redirect!
    assert_match "Unassigned", response.body
    assert_select "tr[data-kind=open]", count: 2
  end

  test "a new call can copy and link slots from another call" do
    post show_calls_path(shows(:saturday)), params: {
      link_call_id: calls(:load_in).id,
      slot_count: 9,
      call: {
        location_id: locations(:main).id,
        call_type_id: call_types(:show_call).id,
        starts_at: "2026-10-18T22:00",
        ends_at: "2026-10-19T01:00"
      }
    }

    call = shows(:saturday).calls.order(:created_at).last
    assert_redirected_to call
    assert_equal 2, call.call_slots.count
    assert_equal [ position_labels(:deck).id, position_labels(:foh).id ], call.call_slots.order(:sort_order).pluck(:position_label_id)
    assert_equal call_slots(:deck_slot), call.call_slots.order(:sort_order).first.partner_slot
    assert_equal call_slots(:foh_slot), call.call_slots.order(:sort_order).second.partner_slot
    follow_redirect!
    assert_match "Linked", response.body
    assert_select "button", text: "Unlink"
  end

  test "scheduling a call and adding slots" do
    post show_calls_path(shows(:saturday)), params: {
      call: {
        location_id: locations(:main).id,
        call_type_id: call_types(:show_call).id,
        starts_at: "2026-10-24T09:00",
        ends_at: "2026-10-24T17:00"
      }
    }

    call = shows(:saturday).calls.order(:created_at).last
    assert_redirected_to call
    assert_equal Time.find_zone("America/New_York").parse("2026-10-24 09:00"), call.starts_at

    post call_call_slots_path(call), params: {
      call_slot: { position_label_id: position_labels(:deck).id },
      count: 3
    }

    assert_equal 3, call.call_slots.count
    assert_equal [ 1, 2, 3 ], call.call_slots.order(:sort_order).pluck(:sort_order)
  end

  test "a call that ends before it starts is rejected" do
    post show_calls_path(shows(:saturday)), params: {
      call: {
        location_id: locations(:main).id,
        call_type_id: call_types(:show_call).id,
        starts_at: "2026-10-24T17:00",
        ends_at: "2026-10-24T09:00"
      }
    }

    assert_response :unprocessable_entity
  end

  test "a location from another venue is rejected" do
    post show_calls_path(shows(:saturday)), params: {
      call: {
        location_id: locations(:other_room).id,
        call_type_id: call_types(:show_call).id,
        starts_at: "2026-10-24T09:00",
        ends_at: "2026-10-24T17:00"
      }
    }

    assert_response :unprocessable_entity
  end

  test "the slot picker groups lists and marks unavailable people" do
    list = venues(:one).template_lists.create!(name: "Regulars")
    list.add_employee(employees(:alex))

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
    Question.open_fill_offer(employee: employees(:alex), call: calls(:load_in))

    get call_path(calls(:load_in))

    assert_select "tr[data-kind=open] span", text: "Open"
    assert_select ".assign-flyout-button", text: "Regulars"
    assert_select ".assign-flyout-button", text: "All employees"
    assert_select "input[aria-label='Search employees']"
    assert_select ".assign-option.is-unavailable", text: /Cole, Blair/
    assert_select ".assign-option.is-unavailable", text: /Time conflict/
    assert_select ".assign-option.is-unavailable", text: /Declined/
    assert_select ".assign-option.is-unavailable", text: /Rivera, Alex/
    assert_select ".assign-option.is-unavailable", text: /Waiting for a reply/
    assert_select ".assign-option.is-unavailable:not([disabled])", text: /Cole, Blair/
    assert_select "ul.slot-history li", text: /Ng, Casey · Declined/
  end
end
