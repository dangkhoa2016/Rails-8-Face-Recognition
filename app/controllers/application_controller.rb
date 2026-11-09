class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  before_action :load_current_user
  around_action :with_locale
  before_action :require_authentication
  helper_method :current_user, :registration_available?, :email_delivery_available?, :selected_theme

  private

  def load_current_user
    Current.user = nil
    user = request.env.fetch("warden").user(:user)
    if user&.authenticate_session?(session[:session_nonce])
      Current.user = user
    else
      sign_out(:user) if user
      session.delete(:session_nonce)
    end
  end

  def with_locale(&block)
    locale = cookies.signed[:locale].to_s
    locale = current_user.preferred_locale if locale.blank? && current_user
    locale = "en" unless %w[en vi].include?(locale)
    I18n.with_locale(locale, &block)
  end

  def current_user
    Current.user
  end

  def registration_available?
    ENV.fetch("PUBLIC_REGISTRATION_ENABLED", "true") == "true" && EmailDelivery.available?
  end

  def email_delivery_available?
    EmailDelivery.available?
  end

  def selected_theme
    theme = cookies.signed[:theme]
    %w[light dark auto].include?(theme) ? theme : "auto"
  end

  def require_authentication
    return if current_user
    redirect_to sign_in_path, alert: I18n.t("auth.sign_in_required")
  end

  def render_rate_limited
    response.headers["Retry-After"] = "900"
    render template: "shared/rate_limited", status: :too_many_requests
  end

  def audit!(action, record, details: {})
    AdminAuditEvent.create!(actor: current_user, action: action, subject_type: record.class.name,
      subject_id: record.id, details: details)
  end
end
