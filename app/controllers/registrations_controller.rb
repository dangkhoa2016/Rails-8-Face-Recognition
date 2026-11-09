class RegistrationsController < ApplicationController
  skip_before_action :require_authentication

  def new
    @user = User.new
  end

  def create
    Auth::RateLimiter.consume!(action: :register, email: params.dig(:user, :email), ip: request.remote_ip)
    return redirect_to new_registration_path, alert: t("auth.registration_disabled") unless registration_available?

    @user = User.new(params.require(:user).permit(:email, :password, :password_confirmation))
    unless params[:accept_terms] == "1"
      @user.errors.add(:base, t("auth.must_accept_terms"))
      return render :new, status: :unprocessable_entity
    end
    if params.dig(:user, :password_confirmation).blank? || params.dig(:user, :password_confirmation) != params.dig(:user, :password)
      @user.errors.add(:password_confirmation, t("auth.passwords_mismatch"))
      return render :new, status: :unprocessable_entity
    end
    normalized_email = @user.email.to_s.strip.downcase.first(254)
    if User.exists?(email: normalized_email)
      # Always use a generic response and never email an already-registered address.
      return redirect_to sign_in_path, notice: t("auth.registration_generic")
    end
    @user.role = "member"  # Never permit role, verification, locale or disabled_at from the request.
    @user.preferred_locale = I18n.locale.to_s
    if @user.save
      @user.update_column(:verification_sent_at, Time.current)
      UserMailer.verify_email(@user).deliver_later
      redirect_to sign_in_path, notice: t("auth.registration_generic")
    else
      render :new, status: :unprocessable_entity
    end
  rescue Auth::RateLimiter::Limited
    render_rate_limited
  rescue ActiveRecord::RecordNotUnique
    redirect_to sign_in_path, notice: t("auth.registration_generic")
  rescue ActiveJob::EnqueueError => error
    Rails.logger.error("Registration email enqueue failure: #{error.class.name}")
    redirect_to sign_in_path, notice: t("auth.email_queue_unavailable")
  end
end
