require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "the same name can exist at another venue but not twice here" do
    copy = venues(:other).locations.create!(name: locations(:main).name)
    assert copy.persisted?

    duplicate = venues(:one).locations.build(name: "main stage")
    assert_not duplicate.valid?
  end

  test "a location used by a call stays" do
    location = locations(:main)

    assert_not location.destroy
    assert location.errors[:base].any?
    assert Location.exists?(location.id)
  end

  test "an unused location can be deleted" do
    location = venues(:one).locations.create!(name: "Shop")

    assert location.destroy
    assert_not Location.exists?(location.id)
  end
end
