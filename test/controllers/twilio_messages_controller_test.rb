require "test_helper"

class TwilioMessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @token = "test-token"
    @previous_token = ENV["TWILIO_AUTH_TOKEN"]
    ENV["TWILIO_AUTH_TOKEN"] = @token
    employees(:alex).update!(mobile: "555-555-0100")
  end

  teardown do
    @previous_token.nil? ? ENV.delete("TWILIO_AUTH_TOKEN") : ENV["TWILIO_AUTH_TOKEN"] = @previous_token
  end

  test "a signed YES confirms the open question" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    assignment.ask_or_confirm

    post twilio_messages_path, params: { From: "+15555550100", Body: "YES" }, headers: signed_headers(From: "+15555550100", Body: "YES")

    assert_response :success
    assert_equal "text/xml", response.media_type
    assert_equal "confirmed_by_reply", assignment.reload.confirmation
    assert_equal "YES", employees(:alex).messages.where(direction: "inbound").last.body
  end

  test "a bad signature is refused" do
    post twilio_messages_path, params: { From: "+15555550100", Body: "YES" }, headers: { "X-Twilio-Signature" => "nope" }

    assert_response :forbidden
    assert_equal 0, employees(:alex).messages.count
  end

  test "an unknown number is acknowledged and not stored" do
    post twilio_messages_path, params: { From: "+15555550999", Body: "YES" }, headers: signed_headers(From: "+15555550999", Body: "YES")

    assert_response :success
    assert_equal 0, Message.count
  end

  private
    def signed_headers(params)
      signature = Messaging::TwilioGateway.signature("http://www.example.com/twilio/messages", params, @token)
      { "X-Twilio-Signature" => signature }
    end
end
