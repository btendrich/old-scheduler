require "test_helper"

class MessagingTest < ActiveSupport::TestCase
  test "the test suite uses the fake gateway" do
    assert_instance_of Messaging::FakeGateway, Messaging.gateway
  end

  test "test environment ignores a configured twilio adapter" do
    gateway = Messaging.gateway(env: "test", adapter: "twilio")

    assert_instance_of Messaging::FakeGateway, gateway
    assert_not Messaging.live?(env: "test", adapter: "twilio")
  end

  test "development uses the simulator unless another adapter is chosen" do
    assert_instance_of Messaging::SimulatorGateway, Messaging.gateway(env: "development", adapter: "simulator")
    assert_instance_of Messaging::TwilioGateway, Messaging.gateway(env: "development", adapter: "twilio")
    assert Messaging.live?(env: "production", adapter: "twilio")
    assert_not Messaging.live?(env: "development", adapter: "simulator")
  end

  test "an unknown adapter is rejected outside test" do
    error = assert_raises(ArgumentError) do
      Messaging.gateway(env: "production", adapter: "carrier-pigeon")
    end

    assert_match "carrier-pigeon", error.message
  end

  test "the simulator accepts a delivery and twilio refuses to send without credentials" do
    assert_nil Messaging::SimulatorGateway.new.deliver(to: "555-0100", body: "Hi")

    assert_raises(Messaging::DeliveryError) do
      Messaging::TwilioGateway.new.deliver(to: "555-0100", body: "Hi")
    end
  end

  test "the fake gateway records deliveries" do
    gateway = Messaging::FakeGateway.new

    gateway.deliver(to: "+15555550100", body: "Reply YES or NO")

    assert_equal [ { to: "+15555550100", body: "Reply YES or NO" } ], gateway.deliveries
  end
end
