require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup { travel_to Time.utc(2026, 10, 17, 16, 0, 0) }

  test "a desk ask is the user, a YES book is the employee" do
    Current.session = users(:one).sessions.create!
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    assignment.ask_or_confirm
    Current.reset

    asked = AuditLog.find_by!(kind: "asked")
    assert_equal users(:one), asked.actor
    assert_equal "one@example.com", asked.actor_name
    assert_equal calls(:load_in), asked.call
    assert_equal assignment_for(employees(:alex)), asked.subject
    assert_match "Alex", asked.detail
    assert_match "Deck", asked.detail
    assert_includes calls(:load_in).outcome_logs, asked

    process = start_fill(slots: [ call_slots(:foh_slot) ], people: [ employees(:blair) ])
    Messaging::Receive.new.call(employee: employees(:blair), body: "YES")

    booked = AuditLog.find_by!(kind: "booked")
    assert_equal employees(:blair), booked.actor
    assert_equal employees(:blair).name, booked.actor_name
    assert_equal process, booked.fill_process
    assert_match "FOH", booked.detail
    assert_match "fill #{process.number}", booked.detail
    assert_includes calls(:load_in).outcome_logs, booked
  end

  test "a later NO is the employee leaving the slot" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "confirmed_by_desk"
    )

    Backout.release(assignment)

    entry = AuditLog.find_by!(kind: "backed_out")
    assert_equal employees(:alex), entry.actor
    assert_equal assignment, entry.subject
    assert_not_includes calls(:load_in).outcome_logs.where(kind: "asked"), entry
  end

  test "choosing a name does not write a line until they are asked" do
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )

    assert_equal 0, AuditLog.where(subject: assignment).count

    assignment.ask_or_confirm

    assert_equal [ "asked" ], AuditLog.where(subject: assignment).pluck(:kind)
  end

  private
    def assignment_for(employee)
      call_slots(:deck_slot).assignments.find_by!(employee: employee)
    end

    def start_fill(slots:, people:)
      process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
      slots.each { |slot| process.slots.create!(call_slot: slot) }
      people.each { |person| process.add_employee(person) }
      process.start!
      process
    end
end
