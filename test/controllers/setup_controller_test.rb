require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "adding a location, call type, and position label" do
    post locations_path, params: { location: { name: "Rehearsal room" } }
    post call_types_path, params: { call_type: { name: "Load in" } }
    post position_labels_path, params: { position_label: { name: "LX" } }

    assert_redirected_to setup_path
    assert venues(:one).locations.exists?(name: "Rehearsal room")
    assert venues(:one).call_types.exists?(name: "Load in")
    assert venues(:one).position_labels.exists?(name: "LX")
  end

  test "a location, call type, and position label can be renamed" do
    get setup_path

    assert_desk_live
    assert_select "input[aria-label='Rename Main stage']"
    assert_select "input[aria-label='Rename Show']"
    assert_select "input[aria-label='Rename Deck']"

    patch location_path(locations(:main)), params: { location: { name: "  House  " } }
    patch call_type_path(call_types(:show_call)), params: { call_type: { name: "Performance" } }
    patch position_label_path(position_labels(:deck)), params: { position_label: { name: "Deck audio" } }

    assert_redirected_to setup_path
    assert_equal "House", locations(:main).reload.name
    assert_equal "Performance", call_types(:show_call).reload.name
    assert_equal "Deck audio", position_labels(:deck).reload.name
  end

  test "a blank or duplicate name is kept" do
    venues(:one).locations.create!(name: "Shop")

    patch location_path(locations(:main)), params: { location: { name: "  " } }

    assert_equal "Main stage", locations(:main).reload.name
    follow_redirect!
    assert_match "blank", response.body

    patch location_path(locations(:main)), params: { location: { name: "shop" } }

    assert_equal "Main stage", locations(:main).reload.name
  end

  test "another venue's list cannot be renamed" do
    patch location_path(locations(:other_room)), params: { location: { name: "Stolen" } }
    assert_response :not_found
    patch call_type_path(call_types(:other_show)), params: { call_type: { name: "Stolen" } }
    assert_response :not_found
    patch position_label_path(position_labels(:other_deck)), params: { position_label: { name: "Stolen" } }
    assert_response :not_found
    assert_equal "Other stage", locations(:other_room).reload.name
    assert_equal "Show", call_types(:other_show).reload.name
    assert_equal "Deck", position_labels(:other_deck).reload.name
  end

  test "a location on a call cannot be deleted" do
    delete location_path(locations(:main))

    assert Location.exists?(locations(:main).id)
    follow_redirect!
    assert_match "dependent", response.body
  end
end
