require "test_helper"

class LoginTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      username: "player",
      display_name: "Player",
      date_of_birth: "2000-01-01",
      skill_level: "beginner",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "a user can log in again after logging out" do
    get root_path
    assert_select "a[href=?]", login_path, text: "Log In"
    get login_path
    assert_response :success
    assert_select "form[action=?]", login_path
    assert_select "a[href=?]", signup_path, text: "Sign Up"

    post login_path, params: { session: { username: "PLAYER", password: "password123" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".header-actions span", "Logged in as: Player"

    delete logout_path
    follow_redirect!
    assert_select ".header-actions a[href=?]", login_path, text: "Log In"

    post login_path, params: { session: { username: "player", password: "password123" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".header-actions span", "Logged in as: Player"
  end

  test "invalid credentials do not sign in and show a generic error" do
    [ { username: "player", password: "wrong" },
      { username: "missing", password: "password123" },
      { username: "player", password: "" } ].each do |credentials|
      post login_path, params: { session: credentials }
      assert_response :unprocessable_entity
      assert_select "[role=alert]", "Invalid username or password."
      assert_select "input[name='session[password]'][value]", false

      get root_path
      assert_select ".header-actions a[href=?]", login_path, text: "Log In"
    end
  end
end
