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
    assert_desk_live
  end

  test "upcoming calls are grouped by the venue day" do
    sign_in_as users(:one)
    later = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: Time.utc(2026, 10, 19, 13, 0, 0),
      ends_at: Time.utc(2026, 10, 19, 22, 0, 0)
    )
    shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: Time.utc(2026, 10, 16, 13, 0, 0),
      ends_at: Time.utc(2026, 10, 16, 22, 0, 0)
    )
    calls(:load_in).fill_processes.create!(status: "needs_more_names")
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed", needs_review: true
    )

    travel_to Time.utc(2026, 10, 17, 16, 0, 0) do
      get root_url
    end

    assert_response :success
    assert_select "h2", text: "Sunday, Oct 18"
    assert_select "h2", text: "Monday, Oct 19"
    assert_select "h2", text: "Friday, Oct 16", count: 0
    assert_select "a[href='#{call_path(calls(:load_in))}']", text: "Saturday Night"
    assert_select "a[href='#{call_path(later)}']", text: "Saturday Night"
    assert_match "1 of 2 filled", response.body
    assert_match "Needs review", response.body
    assert_match "Needs more names", response.body
  end

  test "a day with nothing left to staff says so" do
    sign_in_as users(:one)

    travel_to Time.utc(2027, 1, 1, 16, 0, 0) do
      get root_url
    end

    assert_select "p", text: "No upcoming calls."
  end

  test "a banner shows when texts are not being sent" do
    sign_in_as users(:one)

    get root_url

    assert_select ".messaging-banner", "Texts are not being sent."
  end
end
