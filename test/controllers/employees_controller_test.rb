require "test_helper"

class EmployeesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the list is this venue in order" do
    get employees_path

    assert_response :success
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
      employee: { preferred_name: "Drew", mobile: "555-0130", active: "1" }
    }

    employee = Employee.find_by!(preferred_name: "Drew")
    assert_redirected_to employee
    assert_equal venues(:one).id, employee.venue_id
    assert_equal 4, employee.sort_order
  end

  test "a blank employee is rejected" do
    post employees_path, params: { employee: { preferred_name: "", mobile: "" } }

    assert_response :unprocessable_entity
  end

  test "renaming an employee" do
    patch employee_path(employees(:alex)), params: {
      employee: { preferred_name: "Alexis", mobile: employees(:alex).mobile }
    }

    assert_redirected_to employees(:alex)
    assert_equal "Alexis", employees(:alex).reload.preferred_name
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
    assert_redirected_to employees(:blair)
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
end
