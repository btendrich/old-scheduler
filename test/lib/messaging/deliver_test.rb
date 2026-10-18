require "test_helper"

class Messaging::DeliverTest < ActiveSupport::TestCase
  test "an outbound text is stored and handed to the gateway" do
    gateway = Messaging::FakeGateway.new

    message = Messaging::Deliver.new(gateway: gateway).call(employee: employees(:alex), body: " Can you work? ")

    assert_equal "outbound", message.direction
    assert_equal "Can you work?", message.body
    assert_equal "555-0100", message.mobile
    assert_equal employees(:alex), message.employee
    assert_equal [ { to: "555-0100", body: "Can you work?" } ], gateway.deliveries
  end

  test "a text does not book anyone or open a question" do
    assert_no_difference [ "Assignment.count" ] do
      Messaging::Deliver.new(gateway: Messaging::FakeGateway.new).call(employee: employees(:alex), body: "Hello")
    end
  end

  test "a blank text is not sent" do
    gateway = Messaging::FakeGateway.new

    assert_raises(ActiveRecord::RecordInvalid) do
      Messaging::Deliver.new(gateway: gateway).call(employee: employees(:alex), body: " ")
    end

    assert_empty gateway.deliveries
    assert_equal 0, employees(:alex).messages.count
  end
end
