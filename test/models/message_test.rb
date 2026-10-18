require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "a text keeps the mobile it was sent to and strips the body" do
    message = employees(:alex).messages.create!(
      direction: "outbound",
      body: "  Are you free?  ",
      mobile: " 555-0100 ",
      sent_at: Time.utc(2026, 10, 17, 15, 0, 0)
    )

    assert_equal "Are you free?", message.body
    assert_equal "555-0100", message.mobile
    assert message.outbound?
  end

  test "a blank text is rejected" do
    message = employees(:alex).messages.new(direction: "inbound", body: "  ", mobile: "555-0100", sent_at: Time.current)

    assert_not message.valid?
    assert_includes message.errors[:body], "can't be blank"
  end

  test "deleting an employee deletes their texts" do
    employees(:alex).messages.create!(
      direction: "outbound", body: "Hello", mobile: "555-0100", sent_at: Time.current
    )

    employees(:alex).destroy!

    assert_not Message.exists?(employee_id: employees(:alex).id)
  end
end
