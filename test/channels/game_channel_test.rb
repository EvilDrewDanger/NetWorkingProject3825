require "test_helper"

class GameChannelTest < ActionCable::Channel::TestCase
  test "subscribes to the shared game room" do
    subscribe

    assert subscription.confirmed?
    assert_has_stream "game_room_1"
  end

  test "broadcasts messages to the shared game room" do
    subscribe

    assert_broadcast_on "game_room_1", { message: "Hello", sender: "Player" } do
      perform :send_message, message: "Hello"
    end
  end
end
