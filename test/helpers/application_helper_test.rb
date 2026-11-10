require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "waiting and conflict badges use gold, timed out uses violet" do
    assert_match "bg-amber-50", status_badge("Waiting for a reply")
    assert_match "bg-amber-50", status_badge("Time conflict")
    assert_match "bg-violet-50", status_badge("Timed out")
    assert_match "bg-emerald-50", status_badge("Confirmed by desk")
    assert_match "bg-red-50", status_badge("Declined")
    assert_match "bg-red-50", status_badge("Open")
  end

  test "an unasked release is not slot history; a decline and a cancel are" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    assignment.release!

    assert_not slot_history?(assignment)
    assert_equal "Unconfirmed", slot_release_label(assignment)

    assignment.update!(confirmation: "declined")
    assert slot_history?(assignment)
    assert_equal "Declined", slot_release_label(assignment)
  end

  test "canceling a confirmed name is a cancel in the slot history" do
    Current.session = users(:one).sessions.create!
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk"
    )
    assignment.cancel_text!
    Current.reset

    assert_equal "Cancelled", slot_release_label(assignment.reload)
  end

  test "audit log lines name the actor and the object" do
    Current.session = users(:one).sessions.create!
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    assignment.ask_or_confirm
    Current.reset

    lines = audit_log_lines(AuditLog.chronological, zone: ActiveSupport::TimeZone["America/New_York"])
    assert_match "Asked", lines
    assert_match "one@example.com", lines
    assert_match "Deck", lines
  end

  test "a fill phase badge names the run state" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))

    assert_match "New", fill_phase_badge(process)
    process.update!(status: "filling", started_at: Time.current)
    assert_match "Running", fill_phase_badge(process)
  end
end
