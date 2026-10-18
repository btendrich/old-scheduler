require "test_helper"

class TwilioGatewayTest < ActiveSupport::TestCase
  setup { @previous = stash_twilio_env }

  teardown { restore_twilio_env(@previous) }

  test "a signed request matches Twilio's published example" do
    url = "https://mycompany.com/myapp.php?foo=1&bar=2"
    params = {
      "CallSid" => "CA1234567890ABCDE",
      "Caller" => "+14158675309",
      "Digits" => "1234",
      "From" => "+14158675309",
      "To" => "+18005551212"
    }

    assert_equal "RSOYDt4T1cUTdK1PDd93/VVr8B8=", Messaging::TwilioGateway.signature(url, params, "12345")
  end

  test "delivery posts an E.164 message and a short number is refused" do
    ENV["TWILIO_ACCOUNT_SID"] = "AC123"
    ENV["TWILIO_AUTH_TOKEN"] = "secret"
    ENV["TWILIO_FROM_NUMBER"] = "555-555-0000"
    sent = nil
    gateway = Messaging::TwilioGateway.new(transport: ->(request) {
      sent = request
      Net::HTTPCreated.new("1.1", "201", "Created")
    })

    gateway.deliver(to: "(555) 555-0100", body: "Hello")

    assert_equal "/2010-04-01/Accounts/AC123/Messages.json", sent.path
    assert_equal(
      { "From" => "+15555550000", "To" => "+15555550100", "Body" => "Hello" },
      URI.decode_www_form(sent.body).to_h
    )

    assert_raises(Messaging::DeliveryError) do
      gateway.deliver(to: "555-0100", body: "Hello")
    end
  end

  test "a missing token rejects every signature" do
    ENV.delete("TWILIO_AUTH_TOKEN")

    assert_not Messaging::TwilioGateway.valid_signature?("https://example.com/twilio/messages", { "Body" => "YES" }, "anything")
  end

  test "a failed response is an error" do
    ENV["TWILIO_ACCOUNT_SID"] = "AC123"
    ENV["TWILIO_AUTH_TOKEN"] = "secret"
    ENV["TWILIO_FROM_NUMBER"] = "+15555550000"
    gateway = Messaging::TwilioGateway.new(transport: ->(_) { Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized") })

    assert_raises(Messaging::DeliveryError) do
      gateway.deliver(to: "555-555-0100", body: "Hello")
    end
  end

  private
    def stash_twilio_env
      %w[TWILIO_ACCOUNT_SID TWILIO_AUTH_TOKEN TWILIO_FROM_NUMBER].index_with { |key| ENV[key] }
    end

    def restore_twilio_env(previous)
      previous.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
end
