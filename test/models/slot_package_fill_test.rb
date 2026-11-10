require "test_helper"

class SlotPackageFillTest < ActiveSupport::TestCase
  test "a linked fill offer names both calls and YES books both slots" do
    partner = load_out_slot(position_labels(:deck))
    call_slots(:deck_slot).link_to!(partner)

    process = start_fill(slots: [ call_slots(:deck_slot) ], people: [ employees(:alex) ])
    question = employees(:alex).reload.open_question

    assert_match calls(:load_in).schedule_phrase, question.then { CallText.body_for(question) }
    assert_match partner.call.schedule_phrase, CallText.body_for(question)

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_equal employees(:alex), call_slots(:deck_slot).reload.current_assignment.employee
    assert_equal employees(:alex), partner.reload.current_assignment.employee
    assert_equal "confirmed_by_reply", partner.current_assignment.confirmation
    body = employees(:alex).messages.where("body LIKE ?", "You're confirmed%").last.body
    assert_match calls(:load_in).schedule_phrase, body
    assert_match partner.call.schedule_phrase, body
  end

  test "a package NO leaves the partner open" do
    partner = load_out_slot(position_labels(:deck))
    call_slots(:deck_slot).link_to!(partner)

    start_fill(slots: [ call_slots(:deck_slot) ], people: [ employees(:alex), employees(:blair) ])
    Messaging::Receive.new.call(employee: employees(:alex), body: "NO")

    assert_nil call_slots(:deck_slot).reload.current_assignment
    assert_nil partner.reload.current_assignment
    assert_equal "asked", start_fill_candidate_state(employees(:blair))
  end

  test "a fill cannot claim a slot whose partner is already filled" do
    partner = load_out_slot(position_labels(:deck))
    call_slots(:deck_slot).link_to!(partner)
    partner.assignments.create!(employee: employees(:blair), source: "manual", confirmation: "confirmed_by_desk")

    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    assert_raises(ActiveRecord::RecordInvalid) do
      process.slots.create!(call_slot: call_slots(:deck_slot))
    end
  end

  test "a manual Ask on a linked slot names both calls and YES books both" do
    partner = load_out_slot(position_labels(:deck))
    call_slots(:deck_slot).link_to!(partner)
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )

    Question.open_manual_confirmation(assignment)
    body = CallText.body_for(employees(:alex).reload.open_question)
    assert_match calls(:load_in).schedule_phrase, body
    assert_match partner.call.schedule_phrase, body

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_equal "confirmed_by_reply", assignment.reload.confirmation
    assert_equal employees(:alex), partner.reload.current_assignment.employee
    assert_equal "confirmed_by_reply", partner.current_assignment.confirmation
    confirm = employees(:alex).messages.where("body LIKE ?", "You're confirmed%").last.body
    assert_match calls(:load_in).schedule_phrase, confirm
    assert_match partner.call.schedule_phrase, confirm
  end

  test "unlink lets the partner fill on its own" do
    partner = load_out_slot(position_labels(:deck))
    call_slots(:deck_slot).link_to!(partner)
    call_slots(:deck_slot).unlink!

    process = partner.call.fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: partner)
    process.add_employee(employees(:alex))
    process.start!

    assert_equal "fill_offer", employees(:alex).reload.open_question.kind
    assert_match partner.call.schedule_phrase, CallText.body_for(employees(:alex).open_question)
    assert_no_match calls(:load_in).schedule_phrase, CallText.body_for(employees(:alex).open_question)
  end

  private
    def load_out_slot(label)
      load_out = shows(:saturday).calls.create!(
        location: locations(:main),
        call_type: call_types(:show_call),
        starts_at: calls(:load_in).ends_at,
        ends_at: calls(:load_in).ends_at + 3.hours
      )
      load_out.call_slots.create!(position_label: label)
    end

    def start_fill(slots:, people:)
      process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
      slots.each { |slot| process.slots.create!(call_slot: slot) }
      people.each { |person| process.add_employee(person) }
      process.start!
      @process = process
      process
    end

    def start_fill_candidate_state(employee)
      @process.candidates.find_by!(employee: employee).state
    end
end
