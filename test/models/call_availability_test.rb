require "test_helper"

class CallAvailabilityTest < ActiveSupport::TestCase
  test "one status, in priority order" do
    other = overlapping_call
    other_slot = other.call_slots.create!(position_label: position_labels(:deck))
    other_slot.assignments.create!(employee: employees(:alex), source: "manual", confirmation: "unconfirmed")
    call_slots(:deck_slot).assignments.create!(employee: employees(:alex), source: "manual", confirmation: "unconfirmed")

    assert_equal :on_this_call, availability(employees(:alex)).status

    call_slots(:deck_slot).current_assignment.release!
    declined = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "declined"
    )
    declined.release!

    assert_equal :declined, availability(employees(:alex)).status

    booked = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk"
    )
    booked.release!

    assert_equal :time_conflict, availability(employees(:alex)).status

    other_slot.current_assignment.release!

    assert_equal :available, availability(employees(:alex)).status
    assert_equal :available, availability(employees(:casey)).status
  end

  test "an unconfirmed booking is a conflict, and a released one is not" do
    other = overlapping_call
    assignment = other.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "unconfirmed"
    )

    assert_equal :time_conflict, availability(employees(:blair)).status
    assert availability(employees(:blair)).placeable?

    assignment.release!

    assert_equal :available, availability(employees(:blair)).status
  end

  test "a call that only touches is not a conflict" do
    touching = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: calls(:load_in).ends_at,
      ends_at: calls(:load_in).ends_at + 4.hours
    )
    touching.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "confirmed_by_desk"
    )

    assert_equal :available, availability(employees(:blair)).status
  end

  test "someone already on the call cannot be placed again" do
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "declined"
    )
    row = availability(employees(:alex))

    assert_equal :on_this_call, row.status
    assert_not row.placeable?
  end

  test "the picker list uses the same statuses" do
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    rows = CallAvailability.build_all(venues(:one).employees.ordered, calls(:load_in))

    assert_equal [ employees(:alex), employees(:blair), employees(:casey) ], rows.map(&:employee)
    assert_equal :on_this_call, rows.first.status
    assert_equal "Alex - On this call", rows.first.option_label
    assert_equal "Casey (inactive) - Available", rows.last.option_label
  end

  private
    def availability(employee)
      CallAvailability.new(employee, calls(:load_in))
    end

    def overlapping_call
      shows(:saturday).calls.create!(
        location: locations(:main),
        call_type: call_types(:show_call),
        starts_at: calls(:load_in).starts_at + 1.hour,
        ends_at: calls(:load_in).ends_at + 1.hour
      )
    end
end
