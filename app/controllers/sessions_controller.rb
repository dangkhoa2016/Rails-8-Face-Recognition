class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [:new, :create]

  def new; end

  def create
    Auth::RateLimiter.consume!(action: :login, email: params[:email], ip: request.remote_ip)
    user = User.find_by(email: params[:email].to_s.downcase.strip.first(254))
    if user&.valid_password?(params[:password].to_s) && user.active_for_authentication?
      reset_session
      sign_in(:user, user)
      session[:session_nonce] = user.session_nonce
      redirect_to user.admin? ? admin_root_path : samples_path, notice: t("auth.signed_in")
    else
      flash.now[:alert] = t("auth.invalid_credentials")
      render :new, status: :unprocessable_entity
    end
  rescue Auth::RateLimiter::Limited
    render_rate_limited
  end

  def destroy
    sign_out(:user)
    reset_session
    Current.user = nil
    redirect_to root_path, notice: t("auth.signed_out")
  end
end
