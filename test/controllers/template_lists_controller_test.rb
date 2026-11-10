require "test_helper"

class TemplateListsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the page opens on the venue's default list" do
    regulars = venues(:one).template_lists.create!(name: "Regulars")
    regulars.add_employee(employees(:alex))
    venues(:one).template_lists.create!(name: "A crew")

    get template_lists_path

    assert_response :success
    assert_desk_live
    assert_select "p", text: venues(:one).name
    assert_select "a[aria-current=page]", text: /Regulars/
    assert_select ".list-default", text: "Default"
    assert_select "li.list-member", text: /Alex/
    assert_select "li.list-person.inactive", text: /Casey/
    assert_select "li[data-notes=?]", "Prefers days", count: 0
    assert_no_match "Outsider", response.body
    assert_select ".list-title", text: /Regulars/
    assert_select "button[aria-label='Venue order'][aria-sort=ascending]", text: "Order"
    assert_select "button[aria-label='Name'][aria-sort=none]"
    assert_select "button[aria-label='Skills'][aria-sort=none]"
    assert_select "li.list-person", text: /Blair/ do
      assert_select "span.list-order", text: "2"
    end
    assert_select "input[aria-label=Search]"
    assert_select "button[aria-label='Clear search']"
    assert_select "button", text: "Skill"
    assert_select "button", text: "1 or higher"
    assert_select "ol[data-sortable-url-value=?]", reorder_template_list_template_entries_path(regulars)
    assert_select "li.list-member button[aria-label='Remove Rivera, Alex']"
    assert_select "li.list-member button", text: "Up", count: 0
    assert_select "li.list-member button", text: "Down", count: 0
    assert_select "li.list-person[data-controller=employee-card]"
    assert_select "li.list-member[data-controller=employee-card]"
    assert_match "above normal", response.body
    assert_match "None yet", response.body
    assert_match "Nothing scheduled", response.body
  end

  test "available people show their strongest skills" do
    list = venues(:one).template_lists.create!(name: "Regulars")
    employees(:alex).employee_skills.create!(skill: skills(:deck), level: 5)
    extra = skill_categories(:audio).skills.create!(name: "RF")
    employees(:alex).employee_skills.create!(skill: extra, level: 1)

    get template_lists_path(list: list.id)

    assert_select "li.list-person", text: /Alex/ do
      assert_select "span", text: /Deck audio 5, FOH mixer 4/
      assert_select "span", text: "and 1 more"
    end
    assert_select "li[data-notes=?]", "Prefers days"
  end

  test "another venue's list is not reachable" do
    theirs = venues(:other).template_lists.create!(name: "Theirs")

    get template_lists_path(list: theirs.id)

    assert_response :not_found
  end

  test "a list can be made the default" do
    regulars = venues(:one).template_lists.create!(name: "Regulars")
    crew = venues(:one).template_lists.create!(name: "A crew")

    patch template_list_path(crew), params: { template_list: { default: true } }

    assert_redirected_to template_lists_path(list: crew.id)
    assert crew.reload.default?
    assert_not regulars.reload.default?
  end

  test "deleting the default list leaves another one in its place" do
    regulars = venues(:one).template_lists.create!(name: "Regulars")
    crew = venues(:one).template_lists.create!(name: "A crew")

    delete template_list_path(regulars)

    assert_redirected_to template_lists_path
    assert_not TemplateList.exists?(regulars.id)
    assert crew.reload.default?
  end

  test "chosen people are added in that order and can be removed" do
    list = venues(:one).template_lists.create!(name: "Regulars")

    post template_list_template_entries_path(list), params: { employee_ids: [ employees(:blair).id, employees(:alex).id ] }

    assert_redirected_to template_lists_path(list: list.id)
    assert_equal [ employees(:blair).id, employees(:alex).id ], list.entries.reload.map(&:employee_id)

    delete selected_template_list_template_entries_path(list), params: { ids: [ list.entries.first.id ] }

    assert_redirected_to template_lists_path(list: list.id)
    assert_equal [ employees(:alex).id ], list.entries.reload.map(&:employee_id)
  end

  test "a person from another venue cannot be added" do
    list = venues(:one).template_lists.create!(name: "Regulars")

    post template_list_template_entries_path(list), params: { employee_ids: [ employees(:outsider).id ] }

    assert_response :not_found
    assert_empty list.entries
  end

  test "the x takes one person off the list" do
    list = venues(:one).template_lists.create!(name: "Regulars")
    list.add_employee(employees(:alex))

    delete template_list_template_entry_path(list, list.entries.first)

    assert_redirected_to template_lists_path(list: list.id)
    assert_empty list.entries.reload
  end

  test "the hover card names upcoming work" do
    list = venues(:one).template_lists.create!(name: "Regulars")
    starts = Time.utc(2026, 11, 2, 18, 0, 0)
    call = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: starts,
      ends_at: starts + 4.hours
    )
    call.call_slots.create!(position_label: position_labels(:deck)).assignments.create!(
      employee: employees(:blair),
      source: "manual",
      confirmation: "confirmed_by_desk"
    )

    travel_to Time.utc(2026, 10, 18, 12, 0, 0) do
      get template_lists_path(list: list.id)
    end

    assert_match "Saturday Night · Main stage · Mon 11/2 1:00 PM", response.body
    assert_match "below normal", response.body
    assert_match "Last 3 months", response.body
  end

  test "dragging the list saves that order" do
    list = venues(:one).template_lists.create!(name: "Regulars")
    list.add_employee(employees(:alex))
    list.add_employee(employees(:blair))

    patch reorder_template_list_template_entries_path(list), params: { ids: list.entries.map(&:id).reverse }

    assert_response :no_content
    assert_equal [ employees(:blair).id, employees(:alex).id ], list.entries.reload.map(&:employee_id)
  end
end
