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

  test "a location on a call cannot be deleted" do
    delete location_path(locations(:main))

    assert Location.exists?(locations(:main).id)
    follow_redirect!
    assert_match "dependent", response.body
  end
end
