class VerificationEmailsController < ApplicationController
  skip_before_action :require_authentication

  def new; end

  def create
    Auth::RateLimiter.consume!(action: :verify_resend, email: params[:email], ip: request.remote_ip)
    user = User.find_by(email: params[:email].to_s.strip.downcase.first(254))
    if EmailDelivery.available? && user && !user.verified? && user.enabled? &&
       (user.verification_sent_at.nil? || user.verification_sent_at < 2.minutes.ago)
      user.update!(verification_sent_at: Time.current)
      begin
        UserMailer.verify_email(user).deliver_later
      rescue ActiveJob::EnqueueError => error
        Rails.logger.error("Verification email enqueue failed class=#{error.class.name}")
      end
    end
    redirect_to sign_in_path, notice: t("auth.verification_generic")
  rescue Auth::RateLimiter::Limited
    render_rate_limited
  end
end
