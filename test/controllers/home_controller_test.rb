require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "guests are asked to sign in" do
    get root_url

    assert_redirected_to new_session_url
  end

  test "the desk sees the venue clock" do
    sign_in_as users(:one)

    travel_to Time.utc(2026, 1, 15, 18, 0, 0) do
      get root_url
    end

    assert_response :success
    assert_select "h1", venues(:one).name
    assert_select "time", "1:00 PM EST"
  end

  test "a banner shows when texts are not being sent" do
    sign_in_as users(:one)

    get root_url

    assert_select ".messaging-banner", "Texts are not being sent."
  end
end
