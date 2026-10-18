require "test_helper"

class AssignmentTest < ActiveSupport::TestCase
  test "a slot has one current person, and a release keeps the row" do
    slot = call_slots(:deck_slot)
    first = book(slot, employees(:alex))
    second = slot.assignments.new(employee: employees(:blair), source: "manual", confirmation: "unconfirmed")

    assert_not second.valid?
    assert_includes second.errors[:call_slot_id], "already has someone"

    first.release!

    assert first.released_at
    assert_nil slot.reload.current_assignment
    assert book(slot, employees(:blair))
  end

  test "the same person cannot take two open slots on one call" do
    book(call_slots(:deck_slot), employees(:alex))
    second = call_slots(:foh_slot).assignments.new(employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk")

    assert_not second.valid?
    assert_includes second.errors[:employee], "is already on this call"
  end

  test "release lets that person take another slot on the call" do
    booked = book(call_slots(:deck_slot), employees(:alex), confirmation: "confirmed_by_desk")
    booked.release!

    assert book(call_slots(:foh_slot), employees(:alex)).persisted?
  end

  test "an employee from another venue is rejected" do
    assignment = call_slots(:deck_slot).assignments.new(
      employee: employees(:outsider),
      source: "manual",
      confirmation: "unconfirmed"
    )

    assert_not assignment.valid?
    assert_includes assignment.errors[:employee], "is from another venue"
  end

  test "the desk can place someone who declined or already overlaps another call" do
    declined = book(call_slots(:deck_slot), employees(:alex), confirmation: "declined")
    declined.release!
    assert book(call_slots(:foh_slot), employees(:alex), confirmation: "confirmed_by_desk")

    other = overlapping_call
    other.call_slots.create!(position_label: position_labels(:deck))
      .assignments.create!(employee: employees(:blair), source: "manual", confirmation: "unconfirmed")

    assert book(call_slots(:deck_slot), employees(:blair))
  end

  test "a note is stripped" do
    assignment = book(call_slots(:deck_slot), employees(:alex))
    assignment.update!(note: "  called  ")

    assert_equal "called", assignment.note
  end

  private
    def book(slot, employee, confirmation: "unconfirmed")
      slot.assignments.create!(employee: employee, source: "manual", confirmation: confirmation)
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
