require "test_helper"

class EmergencyFillTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup { travel_to Time.utc(2026, 10, 17, 16, 0, 0) }

  test "a step texts the group and says the spots go to the first replies" do
    dana = hire("Dana", "555-0201")
    eden = hire("Eden", "555-0202")
    fran = hire("Fran", "555-0203")
    process = start_emergency(people: [ dana, eden, fran ], step_size: 2)

    assert_equal "asked", candidate(process, dana).state
    assert_equal "asked", candidate(process, eden).state
    assert_equal "pending", candidate(process, fran).state
    assert_match "First-response fill: 1 spot still open", dana.messages.last.body
    assert_match "The first YES replies get them", dana.messages.last.body
    assert_nil Question.open.find_by(employee: dana).closed_at
    assert_nil Question.open.find_by(employee: eden).closed_at
  end

  test "the next step texts more people and leaves the earlier offers open" do
    dana = hire("Dana", "555-0201")
    eden = hire("Eden", "555-0202")
    process = start_emergency(people: [ dana, eden ], step_size: 1)

    travel_to process.reload.next_step_at do
      perform_enqueued_jobs(only: EmergencyStepJob)
    end

    assert_nil Question.open.find_by!(employee: dana).closed_at
    assert_equal "asked", candidate(process, eden).reload.state
    assert_match "First-response fill", eden.messages.last.body
  end

  test "a NO waits for the next step" do
    dana = hire("Dana", "555-0201")
    eden = hire("Eden", "555-0202")
    process = start_emergency(people: [ dana, eden ], step_size: 1)

    Messaging::Receive.new.call(employee: dana, body: "NO")

    assert_equal "declined", candidate(process, dana).state
    assert_equal 0, eden.messages.count

    travel_to process.reload.next_step_at do
      perform_enqueued_jobs(only: EmergencyStepJob)
    end

    assert_equal "asked", candidate(process, eden).reload.state
  end

  test "the first YES takes an open spot even while other texts are out" do
    dana = hire("Dana", "555-0201")
    eden = hire("Eden", "555-0202")
    process = start_emergency(people: [ dana, eden ], step_size: 2)

    Messaging::Receive.new.call(employee: dana, body: "YES")

    assert_equal dana, call_slots(:deck_slot).reload.current_assignment.employee
    assert_equal "passed", candidate(process, eden).reload.state
    assert_equal "filled", Question.find_by!(employee: eden).close_reason
    assert_equal "Saturday Night is filled.", eden.messages.last.body
    assert_nil call_slots(:deck_slot).assignments.current.find_by(employee: eden)
  end

  test "a slow YES from an earlier step still books while a spot is open" do
    dana = hire("Dana", "555-0201")
    eden = hire("Eden", "555-0202")
    process = start_emergency(
      people: [ dana, eden ],
      step_size: 2,
      slots: [ call_slots(:deck_slot), call_slots(:foh_slot) ]
    )
    OfferTimeoutJob.perform_now(Question.open.find_by!(employee: dana).id)

    Messaging::Receive.new.call(employee: dana, body: "YES")

    assert_equal dana, call_slots(:deck_slot).reload.current_assignment.employee
    assert_equal "asked", candidate(process, eden).reload.state
    assert_nil Question.open.find_by!(employee: eden).closed_at
  end

  test "someone booked, already a NO, or holding a question is not texted" do
    declined = hire("Dana", "555-0201")
    waiting = hire("Eden", "555-0202")
    ready = hire("Fran", "555-0203")
    released = call_slots(:deck_slot).assignments.create!(
      employee: declined, source: "manual", confirmation: "declined"
    )
    released.release!
    other = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: Time.utc(2026, 10, 19, 13, 0, 0),
      ends_at: Time.utc(2026, 10, 19, 22, 0, 0)
    )
    other.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
      employee: waiting, source: "manual", confirmation: "unconfirmed"
    ).ask_or_confirm
    busy = hire("Gray", "555-0204")
    overlap = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: calls(:load_in).starts_at,
      ends_at: calls(:load_in).ends_at
    )
    overlap.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
      employee: busy, source: "manual", confirmation: "confirmed_by_desk"
    )
    slot = calls(:load_in).call_slots.create!(position_label: position_labels(:foh))
    process = start_emergency(people: [ declined, waiting, busy, ready ], step_size: 1, slots: [ slot ])

    assert_equal "passed", candidate(process, declined).state
    assert_equal "pending", candidate(process, waiting).state
    assert_equal "pending", candidate(process, busy).state
    assert_equal "asked", candidate(process, ready).state
    assert_equal 0, waiting.messages.where("body LIKE ?", "%First-response%").count
    assert_equal 0, busy.messages.where("body LIKE ?", "%First-response%").count
  end

  test "running the step early does not also fire the original timer" do
    dana = hire("Dana", "555-0201")
    eden = hire("Eden", "555-0202")
    fran = hire("Fran", "555-0203")
    process = start_emergency(people: [ dana, eden, fran ], step_size: 1)
    original = process.reload.next_step_at

    travel_to 1.minute.from_now do
      process.run_emergency_step!
    end

    travel_to original do
      perform_enqueued_jobs(only: EmergencyStepJob)
    end

    assert_equal "asked", candidate(process, eden).reload.state
    assert_equal "pending", candidate(process, fran).reload.state
  end

  private
    def start_emergency(people:, step_size:, slots: [ call_slots(:deck_slot) ])
      process = calls(:load_in).fill_processes.create!(
        offer_timeout_minutes: 30,
        mode: "emergency",
        step_size: step_size,
        step_minutes: 15
      )
      slots.each { |slot| process.slots.create!(call_slot: slot) }
      people.each { |person| process.add_employee(person) }
      process.start!
      process
    end

    def hire(name, mobile)
      venues(:one).employees.create!(preferred_name: name, mobile: mobile, active: true)
    end

    def candidate(process, employee)
      process.candidates.find_by!(employee: employee)
    end
end
