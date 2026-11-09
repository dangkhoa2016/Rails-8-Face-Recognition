class PreferencesController < ApplicationController
  skip_before_action :require_authentication

  def update
    if params[:locale].present? && %w[en vi].include?(params[:locale])
      cookies.permanent.signed[:locale] = { value: params[:locale], httponly: true, same_site: :lax, secure: Rails.env.production? }
      current_user&.update_column(:preferred_locale, params[:locale])
    end
    if params[:theme].present? && %w[light dark auto].include?(params[:theme])
      cookies.permanent.signed[:theme] = { value: params[:theme], httponly: true, same_site: :lax, secure: Rails.env.production? }
    end
    # Stimulus saves preferences asynchronously: no redirect or page reload.
    return head :no_content if request.format.json?

    # HTML fallback for browsers without JavaScript. Only relative redirects.
    path = request.referer.to_s
    if path.present?
      begin
        ref = URI.parse(path)
        path = ref.request_uri if ref.host == request.host && ref.port == request.port && ref.scheme == request.scheme
      rescue URI::InvalidURIError
        path = nil
      end
    end
    path = root_path unless path.to_s.start_with?("/") && !path.start_with?("//")
    redirect_to path
  end
end
