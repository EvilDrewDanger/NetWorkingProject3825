class SessionsController < ApplicationController
  def new
  end

  def create
    credentials = params.require(:session).permit(:username, :password)
    @username = credentials[:username].to_s
    user = User.where("LOWER(username) = LOWER(?)", @username).first

    if user&.authenticate(credentials[:password].to_s)
      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: "Logged in successfully."
    else
      flash.now[:alert] = "Invalid username or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to root_path, status: :see_other
  end
end
