module Messaging
  ADAPTERS = {
    "simulator" => "Messaging::SimulatorGateway",
    "twilio" => "Messaging::TwilioGateway"
  }.freeze

  def self.gateway(env: Rails.env, adapter: ENV.fetch("MESSAGING_ADAPTER", "simulator"))
    return FakeGateway.new if env.to_s == "test"

    class_name = ADAPTERS[adapter.to_s]
    raise ArgumentError, "unknown messaging adapter: #{adapter}" unless class_name

    class_name.constantize.new
  end

  def self.live?(...)
    gateway(...).is_a?(TwilioGateway)
  end
end
