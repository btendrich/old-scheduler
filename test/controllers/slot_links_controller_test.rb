require "test_helper"

class SlotLinksControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the desk links and unlinks a slot pair" do
    load_out = shows(:saturday).calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: calls(:load_in).ends_at,
      ends_at: calls(:load_in).ends_at + 3.hours
    )
    partner = load_out.call_slots.create!(position_label: position_labels(:deck))

    post call_slot_slot_link_path(call_slots(:deck_slot)), params: { partner_slot_id: partner.id }

    assert_redirected_to call_path(calls(:load_in))
    assert_equal partner, call_slots(:deck_slot).reload.partner_slot

    delete call_slot_slot_link_path(call_slots(:deck_slot))

    assert_redirected_to call_path(calls(:load_in))
    assert_nil call_slots(:deck_slot).reload.partner_slot
  end
end
