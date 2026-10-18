require "test_helper"

class CallsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "a call shows in the venue clock" do
    get call_path(calls(:load_in))

    assert_response :success
    assert_match "Sun 10/18 9:00 AM", response.body
    assert_match "Sun 10/18 6:00 PM", response.body
    assert_match "Deck", response.body
    assert_match "FOH", response.body
  end

  test "scheduling a call and adding slots" do
    post show_calls_path(shows(:saturday)), params: {
      call: {
        location_id: locations(:main).id,
        call_type_id: call_types(:show_call).id,
        starts_at: "2026-10-24T09:00",
        ends_at: "2026-10-24T17:00"
      }
    }

    call = shows(:saturday).calls.order(:created_at).last
    assert_redirected_to call
    assert_equal Time.find_zone("America/New_York").parse("2026-10-24 09:00"), call.starts_at

    post call_call_slots_path(call), params: {
      call_slot: { position_label_id: position_labels(:deck).id },
      count: 3
    }

    assert_equal 3, call.call_slots.count
    assert_equal [ 1, 2, 3 ], call.call_slots.order(:sort_order).pluck(:sort_order)
  end

  test "a call that ends before it starts is rejected" do
    post show_calls_path(shows(:saturday)), params: {
      call: {
        location_id: locations(:main).id,
        call_type_id: call_types(:show_call).id,
        starts_at: "2026-10-24T17:00",
        ends_at: "2026-10-24T09:00"
      }
    }

    assert_response :unprocessable_entity
  end

  test "a location from another venue is rejected" do
    post show_calls_path(shows(:saturday)), params: {
      call: {
        location_id: locations(:other_room).id,
        call_type_id: call_types(:show_call).id,
        starts_at: "2026-10-24T09:00",
        ends_at: "2026-10-24T17:00"
      }
    }

    assert_response :unprocessable_entity
  end
end
