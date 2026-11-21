require "test_helper"

class FriendRoomRegistryTest < ActiveSupport::TestCase
  setup do
    @now = 100.0
    @timers = []
    @rooms = FriendRoomRegistry.new(
      clock: -> { @now },
      scheduler: ->(_delay, &timer) { @timers << timer }
    )
    @host = User.new(id: 1, display_name: "Host")
    @friend = User.new(id: 2, display_name: "Friend")
    @other = User.new(id: 3, display_name: "Other")
  end

  test "reserves two distinct players and tracks multiple connections" do
    room = @rooms.create(@host)
    code = room[:code]
    assert_match(/\A[A-Z0-9]{8}\z/, code)
    assert_equal 1, @rooms.join(code, @host)[:players].size
    assert_equal 2, @rooms.join(code, @friend)[:players].size
    assert_nil @rooms.join(code, @other)
    assert_nil @rooms.for_player(code, @other.id)
    assert_nil @rooms.connect(code, @other.id, "unauthorized")

    @rooms.connect(code, @host.id, "host-1")
    @rooms.connect(code, @host.id, "host-2")
    @rooms.connect(code, @friend.id, "friend")
    room = @rooms.disconnect(code, @host.id, "host-1")
    assert room[:players][0][:online]
    room = @rooms.disconnect(code, @host.id, "host-2")
    assert_not room[:players][0][:online]
    assert room[:players][1][:online]
    assert_nil @rooms.join(code, @other)
  end

  test "expires only after both players are absent for ten continuous seconds" do
    code = @rooms.create(@host)[:code]
    @rooms.join(code, @friend)
    @rooms.connect(code, @host.id, "host")
    @rooms.connect(code, @friend.id, "friend")
    @timers.shift.call
    assert @rooms.for_player(code, @host.id)

    @rooms.disconnect(code, @host.id, "host")
    @now += 20
    assert @rooms.for_player(code, @host.id)
    @rooms.disconnect(code, @friend.id, "friend")
    old_timer = @timers.shift
    @now += 9
    assert @rooms.connect(code, @host.id, "host-again")
    old_timer.call
    assert @rooms.for_player(code, @host.id)

    @rooms.disconnect(code, @host.id, "host-again")
    @now += 9
    assert @rooms.for_player(code, @friend.id)
    @now += 1
    assert_nil @rooms.for_player(code, @friend.id)
    assert_nil @rooms.join(code, @friend)
  end

  test "a newly hosted room expires if no one connects" do
    code = @rooms.create(@host)[:code]
    @now += 10
    @timers.shift.call
    assert_nil @rooms.for_player(code, @host.id)
  end

  test "concurrent joins reserve at most one remaining slot" do
    code = @rooms.create(@host)[:code]
    users = (2..9).map { |id| User.new(id: id, display_name: "Player #{id}") }
    results = users.map { |user| Thread.new { @rooms.join(code, user) } }.map(&:value)

    assert_equal 1, results.compact.size
    assert_equal 2, @rooms.for_player(code, @host.id)[:players].size
  end

  test "either player can be randomly assigned X for the first game" do
    [ "X", "O" ].each_with_index do |mark, index|
      random = Object.new
      random.define_singleton_method(:random_number) { |limit| limit == 2 ? index : 0 }
      rooms = FriendRoomRegistry.new(random: random, scheduler: ->(*) { })
      code = rooms.create(@host)[:code]
      room = rooms.join(code, @friend)

      assert_equal mark, room[:players].first[:mark]
      assert_equal(mark == "X" ? "O" : "X", room[:players].last[:mark])
      assert_equal "X", room[:turn]
    end
  end

  test "validates moves and pauses until both players are connected" do
    code = @rooms.create(@host)[:code]
    @rooms.connect(code, @host.id, "host")
    assert_equal "Waiting for both players to connect.", @rooms.play(code, @host.id, "host", 0)[:error]

    @rooms.join(code, @friend)
    room = @rooms.connect(code, @friend.id, "friend")
    x_user, x_connection, o_user, o_connection = ordered_players(room)
    assert_equal [ "O", "X" ], room[:players].map { |player| player[:mark] }.sort
    assert_equal "X", room[:turn]
    assert_equal "You are not connected to this room.", @rooms.play(code, @other.id, "other", 0)[:error]
    assert_equal "You are not connected to this room.", @rooms.play(code, x_user.id, "unknown", 0)[:error]
    [ -1, 9, "0", nil, 1.0 ].each do |index|
      assert_equal "Invalid square.", @rooms.play(code, x_user.id, x_connection, index)[:error]
    end
    assert_equal "It is not your turn.", @rooms.play(code, o_user.id, o_connection, 0)[:error]

    room = @rooms.play(code, x_user.id, x_connection, 0)[:room]
    assert_equal "X", room[:board][0]
    assert_equal "O", room[:turn]
    assert_equal "That square is already occupied.", @rooms.play(code, o_user.id, o_connection, 0)[:error]
    @rooms.disconnect(code, x_user.id, x_connection)
    assert_equal "Waiting for both players to connect.", @rooms.play(code, o_user.id, o_connection, 1)[:error]
    room = @rooms.connect(code, x_user.id, x_connection)
    assert_equal "X", room[:board][0]
    assert_equal "O", room[:turn]
    assert_equal "O", @rooms.play(code, o_user.id, o_connection, 1)[:room][:board][1]
  end

  test "detects a win and requires both players to agree before swapping marks for a rematch" do
    code, room = connected_room
    x_user, x_connection, o_user, o_connection = ordered_players(room)
    assert_equal "The game is still in progress.", @rooms.request_rematch(code, x_user.id, x_connection)[:error]

    [ [ x_user, x_connection, 0 ], [ o_user, o_connection, 3 ], [ x_user, x_connection, 1 ],
      [ o_user, o_connection, 4 ], [ x_user, x_connection, 2 ] ].each do |user, connection, index|
      room = @rooms.play(code, user.id, connection, index)[:room]
    end
    assert_equal "X", room[:result]
    assert_equal "The game has finished.", @rooms.play(code, o_user.id, o_connection, 5)[:error]

    room = @rooms.request_rematch(code, x_user.id, x_connection)[:room]
    assert_equal "X", room[:result]
    assert room[:players].find { |player| player[:mark] == "X" }[:rematch_requested]
    @rooms.disconnect(code, o_user.id, o_connection)
    assert_equal "Waiting for both players to connect.", @rooms.request_rematch(code, x_user.id, x_connection)[:error]
    @rooms.connect(code, o_user.id, o_connection)
    room = @rooms.request_rematch(code, o_user.id, o_connection)[:room]
    assert_nil room[:result]
    assert_equal Array.new(9), room[:board]
    assert_equal "X", room[:turn]
    assert_equal "O", room[:players].find { |player| player[:name] == x_user.display_name }[:mark]
    assert_equal "X", room[:players].find { |player| player[:name] == o_user.display_name }[:mark]
    assert room[:players].none? { |player| player[:rematch_requested] }
    assert_equal "X", @rooms.play(code, o_user.id, o_connection, 8)[:room][:board][8]
  end

  test "detects a draw" do
    code, room = connected_room
    x_user, x_connection, o_user, o_connection = ordered_players(room)
    [ 0, 1, 2, 4, 3, 5, 7, 6, 8 ].each_with_index do |index, turn|
      user, connection = turn.even? ? [ x_user, x_connection ] : [ o_user, o_connection ]
      room = @rooms.play(code, user.id, connection, index)[:room]
    end
    assert_equal "draw", room[:result]
    assert_equal "The game has finished.", @rooms.play(code, o_user.id, o_connection, 0)[:error]
  end

  private

  def connected_room
    code = @rooms.create(@host)[:code]
    @rooms.join(code, @friend)
    @rooms.connect(code, @host.id, "host")
    [ code, @rooms.connect(code, @friend.id, "friend") ]
  end

  def ordered_players(room)
    room[:players].first[:mark] == "X" ? [ @host, "host", @friend, "friend" ] : [ @friend, "friend", @host, "host" ]
  end
end
