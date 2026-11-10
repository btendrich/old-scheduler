require "test_helper"

class CallSlotsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "reordering slots rewrites the numbers" do
    patch reorder_call_call_slots_path(calls(:load_in)), params: {
      ids: [ call_slots(:foh_slot).id, call_slots(:deck_slot).id ]
    }

    assert_response :no_content
    assert_equal [ call_slots(:foh_slot).id, call_slots(:deck_slot).id ], calls(:load_in).call_slots.order(:sort_order, :id).pluck(:id)
    assert_equal 1, call_slots(:foh_slot).reload.sort_order
    assert_equal 2, call_slots(:deck_slot).reload.sort_order
  end

  test "the slot list uses a number column, one status column, and a fill number" do
    process = calls(:load_in).fill_processes.create!(offer_timeout_minutes: 30)
    process.slots.create!(call_slot: call_slots(:deck_slot))

    get call_path(calls(:load_in))

    assert_select "input[aria-label='Select all slots']"
    assert_select "th.slot-index", text: "#"
    assert_select "td.slot-index", text: "1"
    assert_select "th", text: "Fill", count: 0
    assert_match "Fill #{process.number}", response.body
    assert_select "button[aria-label='Remove slot 1']"
    assert_select ".drag-handle"
  end
end
