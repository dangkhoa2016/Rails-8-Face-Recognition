class EmailVerificationsController < ApplicationController
  skip_before_action :require_authentication

  def show
    @token = params[:token].to_s
    user = User.find_by_token_for(:email_verification, @token)
    @valid = user.present? && !user.verified?
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Cache-Control"] = "no-store"
  end

  def create
    user = User.find_by_token_for(:email_verification, params[:token].to_s)
    return redirect_to new_verification_email_path, alert: t("auth.link_expired") unless user && !user.verified?
    user.update!(email_verified_at: Time.current)
    redirect_to sign_in_path, notice: t("auth.email_verified")
  end
end
