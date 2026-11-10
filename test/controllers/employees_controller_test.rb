require "test_helper"

class EmployeesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the list is this venue in order" do
    get employees_path

    assert_response :success
    assert_desk_live
    assert_select "tbody tr" do |rows|
      assert_match "Alex", rows[0].text
      assert_match "Blair", rows[1].text
      assert_match "Casey", rows[2].text
    end
    assert_no_match "Outsider", response.body
  end

  test "another venue's employee is not reachable" do
    get employee_path(employees(:outsider))

    assert_response :not_found
  end

  test "creating an employee appends them" do
    post employees_path, params: {
      employee: { first_name: "Drew", last_name: "Lane", mobile: "555-0130", active: "1" }
    }

    employee = Employee.find_by!(first_name: "Drew", last_name: "Lane")
    assert_equal "Lane, Drew", employee.name
    assert_redirected_to employee
    assert_equal venues(:one).id, employee.venue_id
    assert_equal 4, employee.sort_order
  end

  test "a blank employee is rejected" do
    post employees_path, params: { employee: { first_name: "", last_name: "", preferred_name: "", mobile: "" } }

    assert_response :unprocessable_entity
  end

  test "renaming an employee" do
    patch employee_path(employees(:alex)), params: {
      employee: { preferred_name: "Alexis", first_name: "Alex", last_name: "Rivera", mobile: employees(:alex).mobile }
    }

    assert_redirected_to employees(:alex)
    assert_equal "Alexis", employees(:alex).reload.preferred_name
    assert_equal "Rivera, Alexis", employees(:alex).name
  end

  test "dragging the roster saves that order" do
    get employees_path

    assert_select "tbody[data-sortable-url-value=?]", reorder_employees_path
    assert_select "button", text: "Venue order"
    assert_select "button", text: "Name"
    assert_select "button", text: "Skill level"

    patch reorder_employees_path, params: { ids: [ employees(:casey).id, employees(:alex).id, employees(:blair).id ] }

    assert_response :no_content
    assert_equal [ employees(:casey), employees(:alex), employees(:blair) ].map(&:id), venues(:one).employees.ordered.pluck(:id)
  end

  test "a drag that is not the whole roster is ignored" do
    patch reorder_employees_path, params: { ids: [ employees(:blair).id, employees(:outsider).id ] }

    assert_response :unprocessable_entity
    assert_equal [ 1, 2, 3 ], venues(:one).employees.ordered.pluck(:sort_order)
  end

  test "moving an employee reorders the list" do
    patch move_higher_employee_path(employees(:blair))

    assert_redirected_to employees_path
    follow_redirect!
    assert_select "tbody tr" do |rows|
      assert_match "Blair", rows[0].text
      assert_match "Alex", rows[1].text
    end
  end

  test "a booked employee stays on the roster" do
    call_slots(:deck_slot).assignments.create!(
      employee: employees(:alex), source: "manual", confirmation: "unconfirmed"
    )

    delete employee_path(employees(:alex))

    assert_redirected_to employees(:alex)
    assert Employee.exists?(employees(:alex).id)
    assert_match "assignments", flash[:alert]
  end

  test "deleting an employee removes their skills" do
    alex_id = employees(:alex).id

    delete employee_path(employees(:alex))

    assert_redirected_to employees_path
    assert_not Employee.exists?(alex_id)
    assert_not EmployeeSkill.exists?(employee_id: alex_id)
  end

  test "adding and correcting a skill" do
    post employee_employee_skills_path(employees(:blair)), params: {
      employee_skill: { skill_id: skills(:foh).id, level: 3, note: " Learning " }
    }

    record = employees(:blair).employee_skills.find_by!(skill: skills(:foh))
    assert_redirected_to edit_employee_path(employees(:blair))
    assert_equal 3, record.level
    assert_equal "Learning", record.note

    patch employee_employee_skill_path(employees(:blair), record), params: {
      employee_skill: { level: 9, note: "nope" }
    }

    follow_redirect!
    assert_match "Level", response.body
    assert_equal 3, record.reload.level
  end

  test "a skill from another venue is refused" do
    post employee_employee_skills_path(employees(:alex)), params: {
      employee_skill: { skill_id: skills(:other_foh).id, level: 3 }
    }

    follow_redirect!
    assert_match "another venue", response.body
    assert_not employees(:alex).skills.exists?(skills(:other_foh).id)
  end

  test "editing an employee maps this venue's skills and the chosen level" do
    get edit_employee_path(employees(:alex))

    assert_response :success
    assert_select "h3", text: "Audio", count: 1
    assert_select ".skill-row", count: 2
    assert_select ".skill-note", count: 2
    assert_select ".skill-clear-slot", count: 2
    assert_select ".skill-row", text: /FOH mixer/ do
      assert_select "button.is-on", count: 1
      assert_select "button.level-pip", count: 5
      assert_select "button[aria-label='FOH mixer, above normal'][aria-pressed=true]"
      assert_select "button.skill-note-text", text: "Can run the festival console"
      assert_select "button[aria-label='Remove FOH mixer']"
    end
    assert_select ".skill-row", text: /Deck audio/ do
      assert_select "button.is-on", count: 0
      assert_select "button[aria-label='Deck audio, well below normal']"
      assert_select "button.skill-note-text", count: 0
      assert_select "button[aria-label='Remove Deck audio']", count: 0
    end
  end
end
