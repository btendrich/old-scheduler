require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the desk can send a one-off text from the employee" do
    post employee_messages_path(employees(:alex)), params: { body: " See you at 9 " }

    message = employees(:alex).messages.last
    assert_redirected_to employees(:alex)
    assert_equal "outbound", message.direction
    assert_equal "See you at 9", message.body

    follow_redirect!
    assert_match "See you at 9", response.body
  end

  test "a blank one-off is refused" do
    post employee_messages_path(employees(:alex)), params: { body: "" }

    assert_redirected_to employees(:alex)
    assert_equal "Write a message first.", flash[:alert]
    assert_equal 0, employees(:alex).messages.count
  end

  test "another venue's employee cannot be texted" do
    post employee_messages_path(employees(:outsider)), params: { body: "Hello" }

    assert_response :not_found
  end
end
