require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the clients pages stay on the desk live stream" do
    get clients_path
    assert_desk_live

    get client_path(clients(:acme))
    assert_desk_live

    get show_path(shows(:saturday))
    assert_desk_live
  end

  test "a client gets a show" do
    post clients_path, params: { client: { name: "Northlight" } }
    client = venues(:one).clients.find_by!(name: "Northlight")
    assert_redirected_to client

    post client_shows_path(client), params: { show: { name: "Opening" } }
    show = client.shows.find_by!(name: "Opening")

    assert_redirected_to show
    assert_equal venues(:one).id, show.venue_id
  end

  test "a show needs a name" do
    post client_shows_path(clients(:acme)), params: { show: { name: "" } }

    assert_response :unprocessable_entity
  end
end
