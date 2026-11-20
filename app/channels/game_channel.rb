class GameChannel < ApplicationCable::Channel
  def subscribed
    stream_from "game_room_1"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def send_message(data)
    ActionCable.server.broadcast(
      "game_room_1", {
        message: data["message"],
        sender: "Player"

      }
    )
  end
end
