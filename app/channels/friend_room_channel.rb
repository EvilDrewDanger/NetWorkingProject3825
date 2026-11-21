class FriendRoomChannel < ApplicationCable::Channel
  def subscribed
    @code = params[:code].to_s
    @connection_id = SecureRandom.uuid
    room = FriendRoomRegistry.instance.connect(@code, current_user.id, @connection_id) if current_user
    return reject unless room

    stream_from stream_name
    ActionCable.server.broadcast(stream_name, room)
  end

  def sync
    room = FriendRoomRegistry.instance.for_player(@code, current_user.id) if current_user
    room ? transmit(room) : reject
  end

  def unsubscribed
    return unless current_user && @connection_id

    room = FriendRoomRegistry.instance.disconnect(@code, current_user.id, @connection_id)
    ActionCable.server.broadcast(stream_name, room) if room
  end

  private

  def stream_name
    "friend_room_#{@code}"
  end
end
