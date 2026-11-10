require "test_helper"

class SlotLinkTest < ActiveSupport::TestCase
  test "a slot links to one partner on the same show" do
    partner = load_out_slot

    link = call_slots(:deck_slot).link_to!(partner)

    assert_equal partner, call_slots(:deck_slot).partner_slot
    assert_equal call_slots(:deck_slot), partner.partner_slot
    assert_equal link, SlotLink.find(link.id)

    assert_raises(ActiveRecord::RecordInvalid) do
      call_slots(:foh_slot).link_to!(partner)
    end
  end

  test "slots on different shows cannot link" do
    other_show = clients(:acme).shows.create!(name: "Other Night")
    other = other_show.calls.create!(
      location: locations(:main),
      call_type: call_types(:show_call),
      starts_at: Time.utc(2026, 10, 25, 13, 0, 0),
      ends_at: Time.utc(2026, 10, 25, 22, 0, 0)
    )
    partner = other.call_slots.create!(position_label: position_labels(:deck))

    assert_raises(ActiveRecord::RecordInvalid) do
      call_slots(:deck_slot).link_to!(partner)
    end
  end

  test "unlink clears both sides" do
    partner = load_out_slot
    call_slots(:deck_slot).link_to!(partner)

    call_slots(:deck_slot).unlink!

    assert_nil call_slots(:deck_slot).reload.partner_slot
    assert_nil partner.reload.partner_slot
  end

  private
    def load_out_slot
      load_out = shows(:saturday).calls.create!(
        location: locations(:main),
        call_type: call_types(:show_call),
        starts_at: calls(:load_in).ends_at,
        ends_at: calls(:load_in).ends_at + 3.hours
      )
      load_out.call_slots.create!(position_label: position_labels(:deck))
    end
end
