class SessionsController < ApplicationController
  def destroy
    reset_session
    redirect_to root_path, status: :see_other
  end
end
