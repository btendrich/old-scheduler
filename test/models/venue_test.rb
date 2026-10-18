require "test_helper"

class VenueTest < ActiveSupport::TestCase
  test "requires a known time zone" do
    venue = Venue.new(name: "Room", time_zone: "Not/AZone")

    assert_not venue.valid?
    assert_includes venue.errors[:time_zone], "is not a known zone"
  end

  test "accepts an ActiveSupport zone name" do
    venue = Venue.new(name: "Room", time_zone: "America/New_York")

    assert venue.valid?
  end
end
