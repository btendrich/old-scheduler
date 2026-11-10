require "test_helper"

class EmployeeTest < ActiveSupport::TestCase
  test "downcases email and strips names" do
    employee = Employee.new(
      first_name: " Drew ",
      last_name: " Lane ",
      preferred_name: " D ",
      mobile: " 555-0140 ",
      email: " Drew@Example.com "
    )

    assert_equal "Drew", employee.first_name
    assert_equal "Lane", employee.last_name
    assert_equal "D", employee.preferred_name
    assert_equal "555-0140", employee.mobile
    assert_equal "drew@example.com", employee.email
  end

  test "the displayed name is last then first, or the preferred name" do
    employee = employees(:alex)

    assert_equal "Rivera, Alex", employee.name

    employee.preferred_name = "Al"
    assert_equal "Rivera, Al", employee.name

    employee.preferred_name = ""
    assert_equal "Rivera, Alex", employee.name
  end

  test "requires a first name, last name, mobile, and a real email when one is given" do
    employee = venues(:one).employees.new(first_name: "", last_name: "", mobile: "", email: "not-an-email")

    assert_not employee.valid?
    assert employee.errors[:first_name].any?
    assert employee.errors[:last_name].any?
    assert employee.errors[:mobile].any?
    assert employee.errors[:email].any?
    assert_empty employee.errors[:preferred_name]
  end

  test "allows a blank email and preferred name" do
    employee = venues(:one).employees.new(first_name: "Drew", last_name: "Lane", mobile: "555-0140", email: "", preferred_name: "")

    assert employee.valid?
    assert_equal "Lane, Drew", employee.name
  end

  test "appends to the venue order" do
    employee = venues(:one).employees.create!(first_name: "Drew", last_name: "Lane", mobile: "555-0140")

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

  test "the skill brief keeps the strongest names and counts the rest" do
    employees(:alex).employee_skills.create!(skill: skills(:deck), level: 5)
    extra = skill_categories(:audio).skills.create!(name: "RF")
    employees(:alex).employee_skills.create!(skill: extra, level: 1)

    brief = employees(:alex).reload.highest_skills

    assert_equal "Deck audio 5, FOH mixer 4", brief[:names]
    assert_equal 1, brief[:more]
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
