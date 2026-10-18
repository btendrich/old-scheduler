require "test_helper"

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  test "the booking text links to a calendar file anyone with the link can open" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk"
    )
    assignment.send_booking_text
    body = employees(:alex).messages.last.body

    assert_match "You're confirmed", body
    assert_no_match(/\bDeck\b/, body)
    url = body.split.last
    assert_match %r{\Ahttp://example.com/calendar/}, url

    get URI.parse(url).path
    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_match "SUMMARY:Saturday Night", response.body
    assert_match "DTSTART;TZID=America/New_York:20261018T090000", response.body

    assignment.send_booking_text
    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "You're confirmed%").count
  end

  test "a bad calendar link is not found" do
    get calendar_path("not-a-real-link")
    assert_response :not_found
  end
end
