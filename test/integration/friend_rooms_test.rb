require "test_helper"

class FriendRoomsTest < ActionDispatch::IntegrationTest
  setup do
    @host = create_user("host")
    @friend = create_user("friend")
    @other = create_user("other")
    @ip = "2001:db8:#{SecureRandom.hex(2)}:#{SecureRandom.hex(2)}::1"
  end

  teardown do
    SessionsController::LOGIN_RATE_LIMIT_STORE.delete("rate-limit:sessions:#{@ip}")
  end

  test "requires a login to create or join rooms" do
    get friend_rooms_path
    assert_redirected_to login_path
    post friend_rooms_path
    assert_redirected_to login_path
    post join_friend_rooms_path, params: { code: "12345678" }
    assert_redirected_to login_path
  end

  test "host shares a code and a friend joins but a third user cannot enter" do
    login(@host)
    get root_path
    assert_select "a[href=?]", friend_rooms_path, text: /Play a Friend/
    post friend_rooms_path
    code = response.location.split("/").last
    assert_match(/\A[A-Z0-9]{8}\z/, code)
    follow_redirect!
    assert_select "strong", code
    assert_select "[data-controller='friend-room']"

    delete logout_path
    login(@friend)
    post join_friend_rooms_path, params: { code: "  #{code.downcase}  " }
    assert_redirected_to friend_room_path(code)
    follow_redirect!
    assert_response :success

    delete logout_path
    login(@other)
    get friend_room_path(code)
    assert_redirected_to friend_rooms_path
    post join_friend_rooms_path, params: { code: code }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", /invalid, expired, or the room is full/
  end

  test "invalid and expired codes show an error" do
    login(@friend)
    [ "invalid!", "00000000" ].each do |code|
      post join_friend_rooms_path, params: { code: code }
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
    end
  end

  private

  def create_user(username)
    User.create!(username: username, display_name: username.capitalize, date_of_birth: "2000-01-01",
      skill_level: "beginner", password: "password123", password_confirmation: "password123")
  end

  def login(user)
    post login_path, params: { session: { username: user.username, password: "password123" } },
      headers: { "REMOTE_ADDR" => @ip }
    assert_redirected_to root_path
  end
end
