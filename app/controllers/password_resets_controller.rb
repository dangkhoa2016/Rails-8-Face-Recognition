class PasswordResetsController < ApplicationController
  skip_before_action :require_authentication

  def new; end

  def create
    Auth::RateLimiter.consume!(action: :password_reset, email: params[:email], ip: request.remote_ip)
    user = User.find_by(email: params[:email].to_s.strip.downcase.first(254))
    if EmailDelivery.available? && user&.verified? && user.enabled?
      begin
        UserMailer.password_reset(user).deliver_later
      rescue ActiveJob::EnqueueError => error
        Rails.logger.error("Password reset enqueue failed class=#{error.class.name}")
      end
    end
    redirect_to sign_in_path, notice: t("auth.reset_generic")
  rescue Auth::RateLimiter::Limited
    render_rate_limited
  end

  def edit
    @token = params[:token].to_s
    @valid = User.find_by_token_for(:password_reset, @token).present?
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"
  end

  def update
    user = User.find_by_token_for(:password_reset, params[:token].to_s)
    return redirect_to new_password_reset_path, alert: t("auth.link_expired") unless user&.enabled?

    if params[:password_confirmation].blank? || params[:password_confirmation] != params[:password]
      @token = params[:token].to_s
      @valid = true
      @errors = [t("auth.passwords_mismatch")]
      return render :edit, status: :unprocessable_entity
    end
    if user.update(password: params[:password], password_confirmation: params[:password_confirmation], session_nonce: SecureRandom.hex(32))
      reset_session
      redirect_to sign_in_path, notice: t("auth.password_changed")
    else
      @token = params[:token].to_s
      @valid = true
      @errors = user.errors.full_messages
      render :edit, status: :unprocessable_entity
    end
  end
end
