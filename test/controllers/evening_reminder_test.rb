require "test_helper"

class EveningReminderFlowTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    sign_in_as users(:one)
    travel_to Time.utc(2026, 10, 17, 22, 0, 0)
  end

  test "the desk sets the reminder, adds a boss, and fires it from the phone" do
    patch setup_path, params: { reminder_time: "17:30" }
    assert_equal 17, venues(:one).reload.reminder_time.utc.hour
    assert_equal 30, venues(:one).reminder_time.min

    post bosses_path, params: { mobile: "555-0900" }
    assert_equal "555-0900", venues(:one).bosses.last.mobile

    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    get phone_path
    assert_match "Fire the evening reminder", response.body

    post phone_reminder_path
    follow_redirect!
    assert_match "Reminder for Saturday Night", response.body

    get call_path(calls(:load_in))
    assert_match "Reminder sent", response.body
  end
end
