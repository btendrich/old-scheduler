require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  test "downcases email and strips names" do
    employee = Employee.new(
      preferred_name: " Drew ",
      legal_name: " Drew Lane ",
      mobile: " 555-0140 ",
      email: " Drew@Example.com "
    )

    assert_equal "Drew", employee.preferred_name
    assert_equal "Drew Lane", employee.legal_name
    assert_equal "555-0140", employee.mobile
    assert_equal "drew@example.com", employee.email
  end

  test "requires a preferred name, mobile, and a real email when one is given" do
    employee = venues(:one).employees.new(preferred_name: "", mobile: "", email: "not-an-email")

    assert_not employee.valid?
    assert employee.errors[:preferred_name].any?
    assert employee.errors[:mobile].any?
    assert employee.errors[:email].any?
  end

  test "allows a blank email" do
    employee = venues(:one).employees.new(preferred_name: "Drew", mobile: "555-0140", email: "")

    assert employee.valid?
  end

  test "appends to the venue order" do
    employee = venues(:one).employees.create!(preferred_name: "Drew", mobile: "555-0140")

    assert_equal 4, employee.sort_order
  end

  test "moves up and down within the venue" do
    alex = employees(:alex)
    blair = employees(:blair)

    blair.move_higher

    assert_equal 1, blair.reload.sort_order
    assert_equal 2, alex.reload.sort_order

    blair.move_lower

    assert_equal 2, blair.reload.sort_order
    assert_equal 1, alex.reload.sort_order
  end

  test "moving the first or last employee leaves the order alone" do
    alex = employees(:alex)
    casey = employees(:casey)

    alex.move_higher
    casey.move_lower

    assert_equal 1, alex.reload.sort_order
    assert_equal 3, casey.reload.sort_order
  end

  test "skill filter follows the venue order and the minimum level" do
    employees(:blair).employee_skills.create!(skill: skills(:foh), level: 5)
    employees(:casey).employee_skills.create!(skill: skills(:foh), level: 3)

    assert_equal [ employees(:alex), employees(:blair), employees(:casey) ], venues(:one).employees.with_skill(skills(:foh)).to_a
    assert_equal [ employees(:blair) ], venues(:one).employees.with_skill(skills(:foh), minimum_level: 5).to_a
    assert_equal [ employees(:alex), employees(:blair) ], venues(:one).employees.active.with_skill(skills(:foh)).to_a
    assert_empty venues(:other).employees.with_skill(skills(:foh))
  end
end
