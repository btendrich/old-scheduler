require "test_helper"
require "turbo/broadcastable/test_helper"

class VenueDeskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include Turbo::Broadcastable::TestHelper

  test "an employee change refreshes every open desk page" do
    venue = venues(:one)
    before = venue.live_revision

    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts venue do
        employees(:alex).update!(notes: "On the desk")
      end
    end

    assert_not_equal before, venue.reload.live_revision
  end

  test "a text refreshes the phone and employee thread" do
    perform_enqueued_jobs do
      assert_turbo_stream_broadcasts venues(:one) do
        employees(:alex).messages.create!(
          direction: "inbound", body: "YES", mobile: employees(:alex).mobile, sent_at: Time.current
        )
      end
    end
  end
end
