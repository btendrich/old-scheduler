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
    assert_match "Awaiting reply", response.body
    assert_match "Reply YES or NO", employees(:alex).messages.last.body
    assert_match "Started", css_select("textarea[aria-label='Call audit log']").text
    assert_match "one@example.com", css_select("textarea[aria-label='Call audit log']").text
  end

  test "a fill list opens on the default list and can be reordered" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))
    alex = process.add_employee(employees(:alex))
    blair = process.add_employee(employees(:blair))
    list = venues(:one).template_lists.create!(name: "Regulars")
    list.add_employee(employees(:alex))
    list.add_employee(employees(:blair))
    spare = venues(:one).template_lists.create!(name: "Spare")
    other = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: calls(:load_in).starts_at + 1.hour,
      ends_at: calls(:load_in).ends_at + 1.hour
    )
    other.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "unconfirmed"
    )
    declined = call_slots(:foh_slot).assignments.create!(
      employee: employees(:casey), source: "manual", confirmation: "declined"
    )
    declined.release!
    Question.open_fill_offer(employee: employees(:alex), call: calls(:load_in))

    get call_path(calls(:load_in))

    assert_select ".fill-root", text: "Main Stage"
    assert_select "ul[data-group=all][hidden] [data-employee-id='#{employees(:blair).id}']"
    assert_select "ul[data-default-list]:not([hidden]) li.is-selected", text: /Alex/
    assert_select "li.fill-person.is-unavailable", text: /Cole, Blair/
    assert_select "li.fill-person.is-unavailable", text: /Time conflict/
    assert_select "li.fill-person.is-unavailable", text: /Ng, Casey/
    assert_select "li.fill-person.is-unavailable", text: /Declined/
    assert_select "li.fill-person.is-unavailable", text: /Rivera, Alex/
    assert_select "li.fill-person.is-unavailable", text: /Waiting for a reply/
    assert_select "ul[data-group='#{spare.id}'][hidden]"
    assert_select ".fill-tree > .tree-root > ul > li" do |branches|
      assert_match "All employees", branches[0].text
      assert_match "Regulars", branches[1].text
      assert_match "Spare", branches[2].text
    end
    assert_select "[data-controller~=fill-source][data-fill-source-process-id-value=?]", process.id.to_s
    assert_select "button[aria-label='Add to fill']"
    assert_select "button[aria-label='Remove from fill']"
    assert_select "button", text: "Delete fill"
    assert_select ".list-remove", count: 0
    assert_select "li.fill-tone-waiting", text: /Waiting for a reply/
    assert_select "li.fill-tone-conflict", text: /Time conflict/
    assert_select "textarea.fill-log"

    patch reorder_fill_process_fill_candidates_path(process), params: { ids: [ blair.id, alex.id ] }

    assert_response :no_content
    assert_equal [ blair, alex ].map(&:id), process.candidates.ordered.pluck(:id)
  end

  test "a selection of people joins the fill in the order they were listed" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))

    post fill_process_fill_candidates_path(process), params: {
      employee_ids: [ employees(:blair).id, employees(:alex).id ]
    }

    assert_redirected_to call_path(calls(:load_in))
    assert_equal [ employees(:blair).id, employees(:alex).id ], process.candidates.ordered.pluck(:employee_id)
  end

  test "the fill list shows who has been texted" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))
    process.add_employee(employees(:alex))
    process.add_employee(employees(:blair))
    process.start!

    get call_path(calls(:load_in))

    assert_select "li.fill-tone-awaiting", text: /Alex/
    assert_select "li.fill-tone-awaiting", text: /Awaiting reply/
    assert_select "li.fill-tone-queued", text: /Blair/
    assert_select "textarea.fill-log", text: /Offer sent/
    assert_select "form[data-turbo-confirm=?]", "Rivera, Alex has a text out. Stopping does not cancel that offer. A YES can still book. Stop this fill?"
    assert_select "button", text: "Delete fill", count: 0
  end

  test "selected names in the queue can be put back" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))
    alex = process.add_employee(employees(:alex))
    blair = process.add_employee(employees(:blair))

    delete selected_fill_process_fill_candidates_path(process), params: { ids: [ alex.id, blair.id ] }

    assert_redirected_to call_path(calls(:load_in))
    assert_empty process.candidates.reload
  end

  test "someone who has been asked stays on the list" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))
    alex = process.add_employee(employees(:alex))
    process.start!

    delete selected_fill_process_fill_candidates_path(process), params: { ids: [ alex.id ] }

    assert_redirected_to call_path(calls(:load_in))
    assert_equal [ alex.id ], process.candidates.reload.pluck(:id)
    follow_redirect!
    assert_match "Rivera, Alex has already been asked", response.body
  end

  test "a fill that is not running can be deleted" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))
    assignment = call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed", fill_process: process
    )

    delete fill_process_path(process)

    assert_redirected_to call_path(calls(:load_in))
    assert_not FillProcess.exists?(process.id)
    assert CallSlot.exists?(call_slots(:deck_slot).id)
    assert_nil assignment.reload.fill_process_id
  end

  test "a running fill cannot be deleted" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30, status: "filling")

    delete fill_process_path(process)

    assert_redirected_to call_path(calls(:load_in))
    assert FillProcess.exists?(process.id)
    follow_redirect!
    assert_match "Stop the fill before deleting it", response.body
    assert_select "button", text: "Delete fill", count: 0
  end

  test "open slots can be added to a fill that already exists" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))

    get call_path(calls(:load_in))

    assert_select "form[action=?]", add_slots_fill_process_path(process) do
      assert_select "input[type=submit][value='Add to this fill']"
    end

    post add_slots_fill_process_path(process), params: { call_slot_ids: [ call_slots(:foh_slot).id ] }

    assert_redirected_to call_path(calls(:load_in))
    assert_equal [ call_slots(:deck_slot).id, call_slots(:foh_slot).id ].sort, process.slots.reload.map(&:call_slot_id).sort
    assert_equal "pending", process.reload.status
  end

  test "a booked slot cannot join a fill" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))
    call_slots(:foh_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )

    post add_slots_fill_process_path(process), params: { call_slot_ids: [ call_slots(:foh_slot).id ] }

    assert_redirected_to call_path(calls(:load_in))
    assert_equal [ call_slots(:deck_slot).id ], process.slots.reload.map(&:call_slot_id)
    follow_redirect!
    assert_match "open slots", response.body
  end

  test "the desk can stop a fill that is sending texts" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30, status: "filling")
    process.slots.create!(call_slot: call_slots(:deck_slot))
    call_slots(:foh_slot).assignments.create!(
      employee: employees(:blair), source: "manual", confirmation: "confirmed_by_desk"
    )

    get call_path(calls(:load_in))

    assert_select "button", text: "Stop"
    assert_select "th", text: "Time left"
    assert_select "tr.slot-tone-open"
    assert_select "tr.slot-tone-confirmed"
    assert_select "span", text: "Running"
    assert_select "span", text: "Confirmed by desk"
    assert_match "Fill 1", response.body
    assert_match "1 x Deck", response.body

    post stop_fill_process_path(process)

    assert_redirected_to call_path(calls(:load_in))
    assert_equal "pending", process.reload.status
    follow_redirect!
    assert_select "button", text: "Start"
    assert_match "Paused", css_select("textarea[aria-label='Call audit log']").text
  end

  test "the phone can run the next emergency step early" do
    dana = venues(:one).employees.create!(first_name: "Dana", last_name: "Crew", mobile: "555-0201", active: true)
    eden = venues(:one).employees.create!(first_name: "Eden", last_name: "Crew", mobile: "555-0202", active: true)
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
