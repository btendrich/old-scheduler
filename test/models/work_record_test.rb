require "test_helper"

class WorkRecordTest < ActiveSupport::TestCase
  test "finished calls count by window and a release does not" do
    now = Time.utc(2026, 10, 18, 16, 0, 0)
    alex = employees(:alex)
    blair = employees(:blair)

    travel_to now do
      recent = book(alex, Time.utc(2026, 9, 1, 13, 0, 0))
      book(alex, Time.utc(2026, 6, 1, 13, 0, 0))
      book(alex, Time.utc(2026, 1, 1, 13, 0, 0))
      book(alex, now - 3.months - 4.hours, now - 3.months)
      book(alex, now - 3.months - 5.hours, now - 3.months - 1.second)
      book(alex, Time.utc(2026, 11, 1, 13, 0, 0))
      book(alex, Time.utc(2026, 12, 1, 13, 0, 0))
      book(alex, now - 1.hour, now + 3.hours)
      dropped = book(alex, Time.utc(2026, 8, 1, 13, 0, 0))
      dropped.call_slots.first.current_assignment.release!
      book(blair, Time.utc(2026, 9, 2, 13, 0, 0))

      records = WorkRecord.for([ alex, blair ])
      record = records.fetch(alex.id)

      assert_equal recent, record.last_worked
      assert_equal 1, record.in_progress.size
      assert_equal [ Time.utc(2026, 11, 1, 13, 0, 0), Time.utc(2026, 12, 1, 13, 0, 0) ], record.upcoming.map(&:starts_at)
      assert_equal 1, record.later_count
      assert_equal({ 3 => 2, 6 => 4, 12 => 5 }, record.counts)
      assert_equal 1, records.fetch(blair.id).counts.fetch(3)
    end
  end

  test "someone with no bookings has an empty record" do
    record = WorkRecord.for([ employees(:casey) ]).fetch(employees(:casey).id)

    assert_nil record.last_worked
    assert_empty record.in_progress
    assert_nil record.next_call
    assert_equal 0, record.later_count
    assert_equal({ 3 => 0, 6 => 0, 12 => 0 }, record.counts)
  end

  private
    def book(employee, starts_at, ends_at = nil)
      call = shows(:saturday).calls.create!(
        location: locations(:main),
        call_type: call_types(:show_call),
        starts_at: starts_at,
        ends_at: ends_at || (starts_at + 4.hours)
      )
      call.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
        employee: employee,
        source: "manual",
        confirmation: "confirmed_by_desk"
      )
      call
    end
end
