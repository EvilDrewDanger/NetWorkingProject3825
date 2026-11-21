require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    test "identifies a signed-in user from the session" do
      user = User.create!(username: "socketuser", display_name: "Socket User", date_of_birth: "2000-01-01",
        skill_level: "beginner", password: "password123", password_confirmation: "password123")

      connect session: { user_id: user.id }
      assert_equal user, connection.current_user
    end

    test "allows the existing guest socket without identifying a user" do
      connect
      assert_nil connection.current_user
    end
  end
end
