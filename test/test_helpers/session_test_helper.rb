module SessionTestHelper
  def assert_desk_live(signed_in: true)
    assert_select "[data-controller~=desk-live]"
    assert_select ".desk-live-warning[hidden]"
    assert_select ".desk-live-warning", text: /Lost connection to the server/
    assert_select ".desk-live-warning", text: /reload when the server is back/
    assert_select "button", text: "Reload the page"
    if signed_in
      assert_select "turbo-cable-stream-source"
      assert_select "meta[name=turbo-refresh-method][content=morph]"
      assert_select "[data-desk-live-url-value=?]", live_path
    else
      assert_select "[data-desk-live-url-value=?]", rails_health_check_path
      assert_select "turbo-cable-stream-source", count: 0
    end
  end

  def sign_in_as(user)
    Current.session = user.sessions.create!

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.destroy!
    cookies.delete("session_id")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end
