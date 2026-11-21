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
end
