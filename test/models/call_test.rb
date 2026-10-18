require "test_helper"

class CallTest < ActiveSupport::TestCase
  test "the calendar file uses the venue clock and leaves the slot off" do
    ics = calls(:load_in).to_ics

    assert_match "SUMMARY:Saturday Night", ics
    assert_match "LOCATION:Main stage", ics
    assert_match "DTSTART;TZID=America/New_York:20261018T090000", ics
    assert_match "DTEND;TZID=America/New_York:20261018T180000", ics
    assert_no_match "Deck", ics
    assert_no_match "FOH", ics
  end

  test "an overnight call ends on the next venue date" do
    call = calls(:load_in)
    call.starts_at = Time.utc(2026, 10, 19, 2, 0, 0)
    call.ends_at = Time.utc(2026, 10, 19, 8, 0, 0)

    assert_match "DTSTART;TZID=America/New_York:20261018T220000", call.to_ics
    assert_match "DTEND;TZID=America/New_York:20261019T040000", call.to_ics
  end

  test "a text names the show, the venue clock, and the place" do
    assert_equal "Saturday Night, Sun 10/18 9:00 AM–6:00 PM, Main stage", calls(:load_in).schedule_phrase
    assert_equal "Saturday Night, Sun 10/18 9:00 AM", calls(:load_in).departure_phrase
  end

  test "the end is after the start, including overnight" do
    call = calls(:load_in)
    call.ends_at = call.starts_at

    assert_not call.valid?
    assert_includes call.errors[:ends_at], "must be after the start"

    call.starts_at = Time.utc(2026, 10, 18, 23, 0, 0)
    call.ends_at = Time.utc(2026, 10, 19, 2, 0, 0)

    assert call.valid?
  end

  test "location and call type belong to the show's venue" do
    call = calls(:load_in)
    call.location = locations(:other_room)

    assert_not call.valid?
    assert_includes call.errors[:location], "is from another venue"

    call.location = locations(:main)
    call.call_type = call_types(:other_show)

    assert_not call.valid?
    assert_includes call.errors[:call_type], "is from another venue"
  end

  test "touching calls do not overlap, and shared time does" do
    call = calls(:load_in)
    touching = Call.new(starts_at: call.ends_at, ends_at: call.ends_at + 1.hour)
    shared = Call.new(starts_at: call.ends_at - 1.minute, ends_at: call.ends_at + 1.hour)

    assert_not call.overlaps?(touching)
    assert call.overlaps?(shared)
  end

  test "a slot label belongs to the call's venue and appends in order" do
    slot = calls(:load_in).call_slots.build(position_label: position_labels(:other_deck))

    assert_not slot.valid?
    assert_includes slot.errors[:position_label], "is from another venue"

    added = calls(:load_in).call_slots.create!(position_label: position_labels(:deck))

    assert_equal 3, added.sort_order
  end
end
