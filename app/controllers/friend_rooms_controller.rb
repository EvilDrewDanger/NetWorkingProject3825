class FriendRoomsController < ApplicationController
  before_action :require_user

  def index
  end

  def create
    room = FriendRoomRegistry.instance.create(current_user)
    redirect_to friend_room_path(room[:code])
  end

  def join
    code = params[:code].to_s.strip.upcase
    room = FriendRoomRegistry.instance.join(code, current_user) if code.match?(/\A[A-Z0-9]{8}\z/)

    if room
      ActionCable.server.broadcast("friend_room_#{code}", room)
      redirect_to friend_room_path(code)
    else
      flash.now[:alert] = "That room code is invalid, expired, or the room is full."
      render :index, status: :unprocessable_entity
    end
  end

  def show
    @room = FriendRoomRegistry.instance.for_player(params[:code], current_user.id)
    return if @room

    redirect_to friend_rooms_path, alert: "That room is unavailable. Host or join a room to continue."
  end

  private

  def require_user
    redirect_to login_path, notice: "Please log in to play with a friend." unless current_user
  end
end
