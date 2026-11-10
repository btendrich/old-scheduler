require "test_helper"

class AuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "choosing a name does not show until they are asked" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }

    get audit_logs_path

    assert_no_match "Asked", response.body
    assert_no_match "Assigned", response.body
    assert_no_match employees(:alex).name, response.body
  end

  test "the audit page lists venue lines and links the call" do
    post call_slot_assignments_path(call_slots(:deck_slot)), params: {
      assignment: { employee_id: employees(:alex).id, confirmation: "unconfirmed" }
    }
    post ask_assignment_path(call_slots(:deck_slot).reload.current_assignment)

    get audit_logs_path

    assert_response :success
    assert_desk_live
    assert_match "Asked", response.body
    assert_no_match "Assigned", response.body
    assert_match "one@example.com", response.body
    assert_match employees(:alex).name, response.body
    assert_select "a[href='#{call_path(calls(:load_in))}']"
  end
end
