require "test_helper"

class FillProcessTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup { travel_to Time.utc(2026, 10, 17, 16, 0, 0) }

  test "a fill texts one available person per open slot" do
    process = start_fill(slots: [ call_slots(:deck_slot) ], people: [ employees(:alex), employees(:blair) ])

    assert_equal "asked", candidate(process, employees(:alex)).state
    assert_equal "pending", candidate(process, employees(:blair)).state
    assert_equal 1, employees(:alex).messages.count
    assert_equal 0, employees(:blair).messages.count
    assert_match "Reply YES or NO", employees(:alex).messages.last.body
    assert_no_match(/\bDeck\b/, employees(:alex).messages.last.body)
  end

  test "YES books one slot and does not text the next person" do
    process = start_fill(
      slots: [ call_slots(:deck_slot), call_slots(:foh_slot) ],
      people: [ employees(:alex), employees(:blair), employees(:casey) ]
    )

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES bring a wrench")

    booked = call_slots(:deck_slot).reload.current_assignment
    assert_equal employees(:alex), booked.employee
    assert_equal "automatic", booked.source
    assert_equal process, booked.fill_process
    assert_equal "bring a wrench", booked.note
    assert booked.needs_review
    assert_equal "asked", candidate(process, employees(:blair)).state
    assert_equal "pending", candidate(process, employees(:casey)).state
    assert_equal 0, employees(:casey).messages.count
  end

  test "NO asks the next person" do
    process = start_fill(slots: [ call_slots(:deck_slot) ], people: [ employees(:alex), employees(:blair) ])

    Messaging::Receive.new.call(employee: employees(:alex), body: "NO")

    assert_equal "declined", candidate(process, employees(:alex)).state
    assert_equal "asked", candidate(process, employees(:blair)).reload.state
    assert_match "Reply YES or NO", employees(:blair).messages.last.body
  end

  test "a timeout asks the next person" do
    process = start_fill(slots: [ call_slots(:deck_slot) ], people: [ employees(:alex), employees(:blair) ])
    question = Question.open.find_by!(employee: employees(:alex))

    OfferTimeoutJob.perform_now(question.id)

    assert_equal "timeout", question.reload.close_reason
    assert_equal "timed_out", candidate(process, employees(:alex)).state
    assert_equal "asked", candidate(process, employees(:blair)).reload.state
  end

  test "a late YES waits when the remaining slot has a text out, and the next NO books them" do
    process = start_fill(slots: [ call_slots(:deck_slot) ], people: [ employees(:alex), employees(:blair) ])
    OfferTimeoutJob.perform_now(Question.open.find_by!(employee: employees(:alex)).id)
    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_equal "parked", candidate(process, employees(:alex)).state
    assert_nil call_slots(:deck_slot).reload.current_assignment

    Messaging::Receive.new.call(employee: employees(:blair), body: "NO")

    assert_equal employees(:alex), call_slots(:deck_slot).reload.current_assignment.employee
    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "%Reply YES or NO%").count
    assert_match "You're confirmed", employees(:alex).messages.last.body
  end

  test "a late YES books immediately when another slot has no text out" do
    process = start_fill(
      slots: [ call_slots(:deck_slot), call_slots(:foh_slot) ],
      people: [ employees(:alex), employees(:blair) ]
    )
    OfferTimeoutJob.perform_now(Question.open.find_by!(employee: employees(:alex)).id)

    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")

    assert_equal employees(:alex), call_slots(:deck_slot).reload.current_assignment.employee
    assert_equal "asked", candidate(process, employees(:blair)).state
  end

  test "a late YES is told the call is filled when the in-flight reply takes the slot" do
    process = start_fill(slots: [ call_slots(:deck_slot) ], people: [ employees(:alex), employees(:blair) ])
    OfferTimeoutJob.perform_now(Question.open.find_by!(employee: employees(:alex)).id)
    Messaging::Receive.new.call(employee: employees(:alex), body: "YES")
    Messaging::Receive.new.call(employee: employees(:blair), body: "YES")

    assert_equal employees(:blair), call_slots(:deck_slot).reload.current_assignment.employee
    assert_equal "passed", candidate(process, employees(:alex)).state
    assert_equal "Saturday Night is filled.", employees(:alex).messages.last.body
  end

  test "someone on this call or already declined is skipped for good" do
    call_slots(:foh_slot).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "confirmed_by_desk"
    )
    declined = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "declined"
    )
    declined.release!
    replacement = calls(:load_in).call_slots.create!(position_label: position_labels(:deck))
    process = start_fill(slots: [ replacement ], people: [ employees(:blair), employees(:alex), employees(:casey) ])

    assert_equal "passed", candidate(process, employees(:blair)).state
    assert_equal "passed", candidate(process, employees(:alex)).state
    assert_equal "asked", candidate(process, employees(:casey)).state
  end

  test "a time conflict stays on the list and the next available person is asked" do
    other = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: calls(:load_in).starts_at + 1.hour,
      ends_at: calls(:load_in).ends_at
    )
    other.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )
    process = start_fill(slots: [ call_slots(:deck_slot) ], people: [ employees(:alex), employees(:blair) ])

    assert_equal "pending", candidate(process, employees(:alex)).state
    assert_equal "asked", candidate(process, employees(:blair)).state
    assert_equal "filling", process.reload.status
  end

  test "a second process on the same call does not ask someone already asked" do
    start_fill(slots: [ call_slots(:deck_slot) ], people: [ employees(:alex) ])
    other = start_fill(slots: [ call_slots(:foh_slot) ], people: [ employees(:alex), employees(:blair) ])

    assert_equal "passed", candidate(other, employees(:alex)).state
    assert_equal "asked", candidate(other, employees(:blair)).state
    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "%Reply YES or NO%").count
  end

  test "the list ending short waits for more names, and a new name is asked" do
    process = start_fill(slots: [ call_slots(:deck_slot) ], people: [])

    assert_equal "needs_more_names", process.reload.status

    process.add_employee(employees(:alex))

    assert_equal "asked", candidate(process, employees(:alex)).state
    assert_equal "filling", process.reload.status
  end

  test "a NO is not asked again" do
    process = start_fill(slots: [ call_slots(:deck_slot), call_slots(:foh_slot) ], people: [ employees(:alex), employees(:blair) ])
    Messaging::Receive.new.call(employee: employees(:alex), body: "NO")

    process.add_employee(employees(:alex))

    assert_equal "declined", candidate(process, employees(:alex)).state
    assert_equal 1, employees(:alex).messages.where("body LIKE ?", "%Reply YES or NO%").count
  end

  test "a skill filter and a template add people in order and skip duplicates" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))
    process.add_with_skill(skills(:foh), minimum_level: 1)

    assert_equal [ employees(:alex) ], process.candidates.ordered.map(&:employee)

    list = venues(:one).template_lists.create!(name: "Saturday")
    list.add_employee(employees(:blair))
    list.add_employee(employees(:alex))
    other = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: Time.utc(2026, 10, 19, 13, 0, 0),
      ends_at: Time.utc(2026, 10, 19, 22, 0, 0)
    )
    other.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "unconfirmed"
    )
    process.add_template(list)

    assert_equal [ employees(:alex), employees(:blair) ], process.candidates.ordered.map(&:employee)
  end

  test "outside the send window the offer waits" do
    process = calls(:load_in).fill_processes.create!(
      offer_timeout_minutes: 30,
      custom_window: true,
      window_start: "09:00",
      window_end: "17:00"
    )
    process.slots.create!(call_slot: call_slots(:deck_slot))
    process.add_employee(employees(:alex))

    travel_to Time.find_zone("America/New_York").parse("2026-10-17 22:00") do
      assert_enqueued_with(job: ResumeFillJob) { process.start! }
      assert_equal 0, employees(:alex).messages.count
    end

    travel_to Time.find_zone("America/New_York").parse("2026-10-18 10:00") do
      perform_enqueued_jobs(only: ResumeFillJob)
      assert_match "Reply YES or NO", employees(:alex).messages.last.body
    end
  end

  test "a manual confirmation also waits for the venue window" do
    venues(:one).update!(send_window_start: "09:00", send_window_end: "17:00")
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )

    travel_to Time.find_zone("America/New_York").parse("2026-10-17 22:00") do
      assert_enqueued_with(job: DeliverWhenOpenJob) { assignment.ask_or_confirm }
      assert_nil employees(:alex).open_question
    end

    travel_to Time.find_zone("America/New_York").parse("2026-10-18 10:00") do
      perform_enqueued_jobs(only: DeliverWhenOpenJob)
      assert_equal "manual_confirmation", employees(:alex).reload.open_question.kind
    end
  end

  test "two fills cannot own one slot" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))
    other = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)

    assert_raises(ActiveRecord::RecordInvalid) do
      other.slots.create!(call_slot: call_slots(:deck_slot))
    end
  end

  private
    def start_fill(slots:, people:)
      process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
      slots.each { |slot| process.slots.create!(call_slot: slot) }
      people.each { |person| process.add_employee(person) }
      process.start!
      process
    end

    def candidate(process, employee)
      process.candidates.find_by!(employee: employee)
    end
end
