require "test_helper"

class Messaging::ReceiveTest < ActiveSupport::TestCase
  test "a reply is stored on that employee's thread" do
    message = Messaging::Receive.new.call(employee: employees(:alex), body: " YES ")

    assert_equal "inbound", message.direction
    assert_equal "YES", message.body
    assert_equal "555-0100", message.mobile
    assert message.inbound?
  end

  test "a reply does not change a booking" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_equal "unconfirmed", assignment.reload.confirmation
    assert_not assignment.needs_review?
  end

  test "a blank reply is rejected" do
    assert_raises(ActiveRecord::RecordInvalid) do
      Messaging::Receive.new.call(employee: employees(:alex), body: " ")
    end

    assert_equal 0, employees(:alex).messages.count
  end
end
