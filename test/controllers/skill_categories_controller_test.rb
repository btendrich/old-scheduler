require "test_helper"

class SkillCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the skills page stays on the desk live stream" do
    get skill_categories_path
    assert_desk_live
  end

  test "adding a category and a skill" do
    post skill_categories_path, params: { skill_category: { name: "Lighting" } }
    category = venues(:one).skill_categories.find_by!(name: "Lighting")
    assert_redirected_to skill_categories_path
    assert_equal 2, category.sort_order

    post skill_category_skills_path(category), params: { skill: { name: "Board op" } }

    skill = category.skills.find_by!(name: "Board op")
    assert_equal 1, skill.sort_order
    follow_redirect!
    assert_match "Board op", response.body
  end

  test "a skill that people have cannot be deleted" do
    delete skill_path(skills(:foh))

    assert Skill.exists?(skills(:foh).id)
    follow_redirect!
    assert_match "dependent", response.body
  end

  test "an empty category can be deleted" do
    category = venues(:one).skill_categories.create!(name: "Video")

    delete skill_category_path(category)

    assert_redirected_to skill_categories_path
    assert_not SkillCategory.exists?(category.id)
  end
end
