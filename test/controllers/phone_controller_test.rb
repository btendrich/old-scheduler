require "test_helper"

class PhoneControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the latest thread is first and a reply lands on it" do
    employees(:blair).messages.create!(
      direction: "outbound", body: "First", mobile: "555-0101", sent_at: Time.utc(2026, 10, 17, 12, 0, 0)
    )
    employees(:alex).messages.create!(
      direction: "outbound", body: "Later", mobile: "555-0100", sent_at: Time.utc(2026, 10, 17, 15, 0, 0)
    )

    get phone_path

    assert_response :success
    assert_select ".phone-roster a" do |links|
      assert_match "Alex", links[0].text
      assert_match "No open question", links[0].text
      assert_match "Blair", links[1].text
      assert_match "Casey", links[2].text
    end
    assert_no_match "Outsider", response.body
    assert_match "Later", response.body

    post phone_replies_path(employees(:alex)), params: { body: "YES" }

    assert_redirected_to phone_employee_path(employees(:alex))
    follow_redirect!
    assert_match "YES", response.body
    assert employees(:alex).messages.order(:sent_at).last.inbound?
  end

  test "a free-text reply is kept as they wrote it" do
    post phone_replies_path(employees(:blair)), params: { body: " Running late " }

    assert_equal "Running late", employees(:blair).messages.last.body
    follow_redirect!
    assert_match "Running late", response.body
  end

  test "a blank reply is refused" do
    post phone_replies_path(employees(:alex)), params: { body: " " }

    assert_redirected_to phone_employee_path(employees(:alex))
    assert_equal "Write a reply first.", flash[:alert]
    assert_equal 0, employees(:alex).messages.count
  end

  test "another venue's employee is not on this phone" do
    get phone_employee_path(employees(:outsider))
    assert_response :not_found

    post phone_replies_path(employees(:outsider)), params: { body: "YES" }
    assert_response :not_found
  end

  test "someone with no texts still has a thread" do
    get phone_employee_path(employees(:casey))

    assert_response :success
    assert_match "No texts yet.", response.body
  end
end
