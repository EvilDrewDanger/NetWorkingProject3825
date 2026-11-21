require "set"

class FriendRoomRegistry
  CODE_LENGTH = 8
  EMPTY_GRACE_PERIOD = 10
  CODE_CHARACTERS = ("A".."Z").to_a.concat(("0".."9").to_a).freeze

  def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
                 scheduler: ->(delay, &block) { Concurrent::ScheduledTask.execute(delay, &block) })
    @rooms = {}
    @mutex = Mutex.new
    @clock = clock
    @scheduler = scheduler
  end

  def create(user)
    @mutex.synchronize do
      begin
        code = Array.new(CODE_LENGTH) { CODE_CHARACTERS[SecureRandom.random_number(CODE_CHARACTERS.length)] }.join
      end while @rooms.key?(code)

      room = { code: code, players: { user.id => player(user) }, version: 0 }
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

      room[:players][user.id] = player(user)
      room[:version] += 1
      snapshot(room)
    end
  end

  def for_player(code, user_id)
    @mutex.synchronize do
      room = find_room(code)
      snapshot(room) if room && room[:players].key?(user_id)
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

  private

  def player(user)
    { name: user.display_name, connections: Set.new }
  end

  def snapshot(room)
    {
      code: room[:code],
      version: room[:version],
      players: room[:players].values.map { |entry| { name: entry[:name], online: entry[:connections].any? } }
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
