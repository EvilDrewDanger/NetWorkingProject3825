require "test_helper"

class FriendRoomChannelTest < ActionCable::Channel::TestCase
  setup do
    @host = User.new(id: 101, display_name: "Host")
    @friend = User.new(id: 102, display_name: "Friend")
    @code = FriendRoomRegistry.instance.create(@host)[:code]
  end

  test "members connect, synchronize room state, and disconnect" do
    stub_connection current_user: @host
    subscribe code: @code
    assert subscription.confirmed?
    assert_has_stream "friend_room_#{@code}"

    perform :sync
    assert_equal "Host", transmissions.last["players"].first["name"]
    assert transmissions.last["players"].first["online"]

    unsubscribe
    assert_not FriendRoomRegistry.instance.for_player(@code, @host.id)[:players].first[:online]
  end

  test "rejects guests and nonmembers" do
    stub_connection current_user: nil
    subscribe code: @code
    assert subscription.rejected?

    stub_connection current_user: @friend
    subscribe code: @code
    assert subscription.rejected?
  end

  test "broadcasts valid moves and reports invalid actions only to the sender" do
    room = FriendRoomRegistry.instance.join(@code, @friend)
    player, other = room[:players].first[:mark] == "X" ? [ @host, @friend ] : [ @friend, @host ]
    FriendRoomRegistry.instance.connect(@code, other.id, "other-connection")
    stub_connection current_user: player
    subscribe code: @code

    assert_broadcasts "friend_room_#{@code}", 1 do
      perform :play, index: 0
    end
    assert_equal "X", FriendRoomRegistry.instance.for_player(@code, player.id)[:board][0]
    assert_no_broadcasts "friend_room_#{@code}" do
      perform :play, index: 1
    end
    assert_equal "It is not your turn.", transmissions.last["error"]
    perform :request_rematch
    assert_equal "The game is still in progress.", transmissions.last["error"]
  end
end
