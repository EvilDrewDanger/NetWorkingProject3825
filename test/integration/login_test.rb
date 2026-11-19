require "test_helper"

class LoginTest < ActionDispatch::IntegrationTest
  setup do
    @ip = "2001:db8:#{SecureRandom.hex(2)}:#{SecureRandom.hex(2)}::1"
    @user = User.create!(
      username: "player",
      display_name: "Player",
      date_of_birth: "2000-01-01",
      skill_level: "beginner",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  teardown do
    SessionsController::LOGIN_RATE_LIMIT_STORE.delete("rate-limit:sessions:#{@ip}")
  end

  test "a user can log in again after logging out" do
    get root_path
    assert_select "a[href=?]", login_path, text: "Log In"
    get login_path
    assert_response :success
    assert_select "form[action=?]", login_path
    assert_select "a[href=?]", signup_path, text: "Sign Up"

    attempt_login(username: "PLAYER", password: "password123")
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".header-actions span", "Logged in as: Player"

    delete logout_path
    follow_redirect!
    assert_select ".header-actions a[href=?]", login_path, text: "Log In"

    attempt_login(username: "player", password: "password123")
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".header-actions span", "Logged in as: Player"
  end

  test "invalid credentials do not sign in and show a generic error" do
    [ { username: "player", password: "wrong" },
      { username: "missing", password: "password123" },
      { username: "player", password: "" } ].each do |credentials|
      attempt_login(**credentials)
      assert_response :unprocessable_entity
      assert_select "[role=alert]", "Invalid username or password."
      assert_select "input[name='session[password]'][value]", false

      get root_path
      assert_select ".header-actions a[href=?]", login_path, text: "Log In"
    end
  end

  test "limits login attempts per IP for three minutes" do
    travel_to Time.current.change(usec: 0) do
      5.times do
        attempt_login(username: "player", password: "wrong")
        assert_response :unprocessable_entity
      end

      attempt_login(username: "player", password: "password123")
      assert_response :too_many_requests
      assert_select "[role=alert]", "Too many login attempts. Please try again later."
      get root_path
      assert_select ".header-actions a[href=?]", login_path, text: "Log In"

      get login_path
      assert_response :success

      other_ip = "2001:db8:#{SecureRandom.hex(2)}:#{SecureRandom.hex(2)}::2"
      begin
        post login_path, params: { session: { username: "player", password: "password123" } },
          headers: { "REMOTE_ADDR" => other_ip }
        assert_redirected_to root_path
        delete logout_path
      ensure
        SessionsController::LOGIN_RATE_LIMIT_STORE.delete("rate-limit:sessions:#{other_ip}")
      end

      travel 2.minutes + 59.seconds
      attempt_login(username: "player", password: "password123")
      assert_response :too_many_requests

      travel 1.second
      attempt_login(username: "player", password: "password123")
      assert_redirected_to root_path
      follow_redirect!
      assert_select ".header-actions span", "Logged in as: Player"
    end
  end

  private

  def attempt_login(username:, password:)
    post login_path, params: { session: { username: username, password: password } },
      headers: { "REMOTE_ADDR" => @ip }
  end
end
