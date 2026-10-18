require "test_helper"

class EmployeeSkillTest < ActiveSupport::TestCase
  test "level is from 1 to 5" do
    skill = employees(:blair).employee_skills.build(skill: skills(:foh), level: 0)
    assert_not skill.valid?

    skill.level = 6
    assert_not skill.valid?

    skill.level = 1
    assert skill.valid?

    skill.level = 5
    assert skill.valid?
  end

  test "an employee has a skill once" do
    duplicate = employees(:alex).employee_skills.build(skill: skills(:foh), level: 1)

    assert_not duplicate.valid?
    assert duplicate.errors[:skill_id].any?
  end

  test "a skill from another venue cannot be added" do
    record = employees(:alex).employee_skills.build(skill: skills(:other_foh), level: 2)

    assert_not record.valid?
    assert_includes record.errors[:skill], "is from another venue"
  end

  test "a category and skill name are unique without regard to case" do
    category = venues(:one).skill_categories.build(name: "audio")
    assert_not category.valid?

    skill = skill_categories(:audio).skills.build(name: "foh mixer")
    assert_not skill.valid?
  end
end
