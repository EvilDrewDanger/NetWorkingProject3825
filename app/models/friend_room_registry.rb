require "set"

class FriendRoomRegistry
  CODE_LENGTH = 8
  EMPTY_GRACE_PERIOD = 10
  CODE_CHARACTERS = ("A".."Z").to_a.concat(("0".."9").to_a).freeze
  WINNING_LINES = [
    [ 0, 1, 2 ], [ 3, 4, 5 ], [ 6, 7, 8 ],
    [ 0, 3, 6 ], [ 1, 4, 7 ], [ 2, 5, 8 ],
    [ 0, 4, 8 ], [ 2, 4, 6 ]
  ].freeze

  def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                 scheduler: ->(delay, &block) { Concurrent::ScheduledTask.execute(delay, &block) },
                 random: SecureRandom)
    @rooms = {}
    @mutex = Mutex.new
    @clock = clock
    @scheduler = scheduler
    @random = random
  end

  def create(user)
    @mutex.synchronize do
      begin
        code = Array.new(CODE_LENGTH) { CODE_CHARACTERS[@random.random_number(CODE_CHARACTERS.length)] }.join
      end while @rooms.key?(code)

      first_mark = @random.random_number(2).zero? ? "X" : "O"
      room = {
        code: code, players: { user.id => player(user, first_mark) }, version: 0,
        board: Array.new(9), turn: "X", result: nil, rematch_votes: Set.new
      }
      @rooms[code] = room
      schedule_expiry(room)
      snapshot(room)
    end
  end

  def join(code, user)
    @mutex.synchronize do
      room = find_room(code)
      return unless room
      return snapshot(room) if room[:players].key?(user.id)
      return if room[:players].size >= 2

      host_mark = room[:players].values.first[:mark]
      room[:players][user.id] = player(user, other_mark(host_mark))
      room[:version] += 1
      snapshot(room)
    end
  end

  def for_player(code, user_id)
    @mutex.synchronize do
      room = find_room(code)
      snapshot(room).merge(player_slot: room[:players].keys.index(user_id)) if room && room[:players].key?(user_id)
    end
  end

  def connect(code, user_id, connection_id)
    @mutex.synchronize do
      room = find_room(code)
      player = room && room[:players][user_id]
      return unless player

      player[:connections].add(connection_id)
      room[:empty_token] = nil
      room[:expires_at] = nil
      room[:version] += 1
      snapshot(room)
    end
  end

  def disconnect(code, user_id, connection_id)
    @mutex.synchronize do
      room = find_room(code)
      player = room && room[:players][user_id]
      return unless player && player[:connections].delete?(connection_id)

      room[:version] += 1
      schedule_expiry(room) if room[:players].values.all? { |entry| entry[:connections].empty? }
      snapshot(room)
    end
  end

  def play(code, user_id, connection_id, index)
    @mutex.synchronize do
      room = find_room(code)
      error = game_action_error(room, user_id, connection_id)
      return { error: error } if error
      return { error: "The game has finished." } if room[:result]
      return { error: "Invalid square." } unless index.is_a?(Integer) && index.between?(0, 8)
      return { error: "It is not your turn." } unless room[:players][user_id][:mark] == room[:turn]
      return { error: "That square is already occupied." } if room[:board][index]

      room[:board][index] = room[:turn]
      if WINNING_LINES.any? { |line| line.all? { |square| room[:board][square] == room[:turn] } }
        room[:result] = room[:turn]
      elsif room[:board].all?
        room[:result] = "draw"
      else
        room[:turn] = other_mark(room[:turn])
      end
      room[:version] += 1
      { room: snapshot(room) }
    end
  end

  def request_rematch(code, user_id, connection_id)
    @mutex.synchronize do
      room = find_room(code)
      error = game_action_error(room, user_id, connection_id)
      return { error: error } if error
      return { error: "The game is still in progress." } unless room[:result]

      if room[:rematch_votes].add?(user_id)
        if room[:rematch_votes].size == 2
          room[:players].each_value { |entry| entry[:mark] = other_mark(entry[:mark]) }
          room[:board] = Array.new(9)
          room[:turn] = "X"
          room[:result] = nil
          room[:rematch_votes].clear
        end
        room[:version] += 1
      end
      { room: snapshot(room) }
    end
  end

  private

  def player(user, mark)
    { name: user.display_name, mark: mark, connections: Set.new }
  end

  def other_mark(mark)
    mark == "X" ? "O" : "X"
  end

  def game_action_error(room, user_id, connection_id)
    return "Room unavailable." unless room
    player = room[:players][user_id]
    return "You are not connected to this room." unless player && player[:connections].include?(connection_id)
    return "Waiting for both players to connect." unless room[:players].size == 2 &&
      room[:players].values.all? { |entry| entry[:connections].any? }

    nil
  end

  def snapshot(room)
    {
      code: room[:code],
      version: room[:version],
      players: room[:players].map do |id, entry|
        { name: entry[:name], mark: entry[:mark], online: entry[:connections].any?,
          rematch_requested: room[:rematch_votes].include?(id) }
      end,
      board: room[:board].dup,
      turn: room[:turn],
      result: room[:result]
    }
  end

  def find_room(code)
    room = @rooms[code]
    if room && room[:expires_at] && @clock.call >= room[:expires_at]
      @rooms.delete(code)
      return
    end
    room
  end

  def schedule_expiry(room)
    token = Object.new
    room[:empty_token] = token
    room[:expires_at] = @clock.call + EMPTY_GRACE_PERIOD
    code = room[:code]
    @scheduler.call(EMPTY_GRACE_PERIOD) do
      @mutex.synchronize do
        current = @rooms[code]
        @rooms.delete(code) if current && current[:empty_token].equal?(token)
      end
    end
  end

  INSTANCE = new

  def self.instance
    INSTANCE
  end
end
