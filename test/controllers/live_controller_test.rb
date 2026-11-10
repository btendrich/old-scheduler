require "test_helper"

class LiveControllerTest < ActionDispatch::IntegrationTest
  test "the pulse returns the venue revision" do
    sign_in_as users(:one)
    get live_path

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal venues(:one).live_revision, body["revision"]
  end

  test "the pulse requires a desk session" do
    get live_path

    assert_redirected_to new_session_path
  end
end
