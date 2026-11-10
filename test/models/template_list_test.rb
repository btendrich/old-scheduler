require "test_helper"

class TemplateListTest < ActiveSupport::TestCase
  test "the first list is the default and the next one is not" do
    first = venues(:one).template_lists.create!(name: "Regulars")
    second = venues(:one).template_lists.create!(name: "A crew")

    assert first.default?
    assert_not second.default?
  end

  test "making a list the default clears the previous one" do
    first = venues(:one).template_lists.create!(name: "Regulars")
    second = venues(:one).template_lists.create!(name: "A crew")

    second.make_default!

    assert second.reload.default?
    assert_not first.reload.default?
  end

  test "deleting the default list hands it to the next one" do
    first = venues(:one).template_lists.create!(name: "Regulars")
    second = venues(:one).template_lists.create!(name: "A crew")

    first.destroy!

    assert second.reload.default?
  end
end
