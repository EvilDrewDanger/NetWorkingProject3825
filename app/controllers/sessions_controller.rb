class SessionsController < ApplicationController
  LOGIN_RATE_LIMIT_STORE = ActiveSupport::Cache::FileStore.new(
    Rails.root.join("tmp", "login-rate-limits", Rails.env)
  )

  rate_limit to: 5, within: 3.minutes, only: :create, store: LOGIN_RATE_LIMIT_STORE,
    with: -> {
      flash.now[:alert] = "Too many login attempts. Please try again later."
      render :new, status: :too_many_requests
    }

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
