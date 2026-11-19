require "test_helper"

class SignupTest < ActionDispatch::IntegrationTest
  test "homepage links to signup" do
    get root_path
    assert_response :success
    assert_select "h1", "Ready to Play Tic Tac Toe?"
    assert_select "a[href=?]", signup_path, text: "Sign Up"

    get signup_path
    assert_response :success
    assert_select "form[action=?]", users_path
  end

  test "registers a user and displays confirmation" do
    assert_difference "User.count", 1 do
      post users_path, params: { user: valid_user }
    end

    user = User.find_by!(username: "player")
    assert user.authenticate("password123")
    assert_redirected_to root_path
    follow_redirect!
    assert_select "[role=status]", "Account created!"
  end

  test "invalid submissions show errors without creating a user" do
    assert_no_difference "User.count" do
      post users_path, params: { user: valid_user.merge(username: "", skill_level: "invalid") }
    end
    assert_response :unprocessable_entity
    assert_select "li", /Username/
    assert_select "li", /Skill level/
  end

  test "usernames are unique regardless of case" do
    User.create!(valid_user)
    assert_no_difference "User.count" do
      post users_path, params: { user: valid_user.merge(username: "PLAYER") }
    end
    assert_response :unprocessable_entity
    assert_select "li", /Username has already been taken/
  end

  private

  def valid_user
    {
      username: "player",
      display_name: "Player",
      date_of_birth: "2000-01-01",
      skill_level: "beginner",
      password: "password123",
      password_confirmation: "password123"
    }
  end
end
