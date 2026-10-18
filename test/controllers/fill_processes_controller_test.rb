require "test_helper"

class FillProcessesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the desk starts a fill from the call" do
    post call_fill_processes_path(calls(:load_in)), params: {
      call_slot_ids: [ call_slots(:deck_slot).id ],
      fill_process: { offer_timeout_minutes: 45, custom_window: "0" }
    }
    process = calls(:load_in).fill_processes.order(:created_at).last
    assert_redirected_to call_path(calls(:load_in))

    post fill_process_fill_candidates_path(process), params: { employee_id: employees(:alex).id }
    post start_fill_process_path(process)

    follow_redirect!
    assert_match "Alex", response.body
    assert_match "Asked", response.body
    assert_match "Reply YES or NO", employees(:alex).messages.last.body
  end

  test "the phone can run the next emergency step early" do
    dana = venues(:one).employees.create!(preferred_name: "Dana", mobile: "555-0201", active: true)
    eden = venues(:one).employees.create!(preferred_name: "Eden", mobile: "555-0202", active: true)
    post call_fill_processes_path(calls(:load_in)), params: {
      call_slot_ids: [ call_slots(:deck_slot).id ],
      fill_process: { offer_timeout_minutes: 30, mode: "emergency", step_size: 1, step_minutes: 15, custom_window: "0" }
    }
    process = calls(:load_in).fill_processes.order(:id).last
    post fill_process_fill_candidates_path(process), params: { employee_id: dana.id }
    post fill_process_fill_candidates_path(process), params: { employee_id: eden.id }
    post start_fill_process_path(process)

    get phone_employee_path(dana)
    assert_match "Run the next emergency step", response.body

    post phone_emergency_step_path(dana)

    assert_match "First-response fill: 1 spot still open", eden.messages.last.body
    assert_nil dana.reload.open_question.closed_at
  end

  test "another venue's call cannot be filled from here" do
    other_client = venues(:other).clients.create!(name: "Elsewhere")
    other_show = other_client.shows.create!(name: "Night")
    other_call = other_show.calls.create!(
      location: locations(:other_room),
      call_type: call_types(:other_show),
      starts_at: Time.utc(2026, 10, 18, 13, 0, 0),
      ends_at: Time.utc(2026, 10, 18, 22, 0, 0)
    )

    post call_fill_processes_path(other_call), params: {
      call_slot_ids: [],
      fill_process: { offer_timeout_minutes: 30 }
    }

    assert_response :not_found
  end
end
