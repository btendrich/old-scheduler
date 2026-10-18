require "test_helper"

class ShowTest < ActiveSupport::TestCase
  test "a show belongs to a client" do
    show = Show.new(name: "Opening")

    assert_not show.valid?
    assert show.errors[:client].any?
  end
end
