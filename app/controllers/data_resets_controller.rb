class DataResetsController < ApplicationController
  def index
    @resets = current_user.data_resets.order(created_at: :desc).limit(30)
  end

  def show
    @reset = current_user.data_resets.find(params[:id])
  end

  def create
    Auth::RateLimiter.consume!(action: :data_reset, email: current_user.email, ip: request.remote_ip)
    scope = params[:scope].to_s
    raise ActionController::BadRequest unless DataReset::SCOPES.include?(scope)
    if scope != "mine"
      return head :forbidden unless current_user.admin?
      required = scope == "probe_cache" ? "RESET PROBE CACHE" : "RESET ALL TEST DATA"
    else
      required = "RESET MY DATA"
    end
    return redirect_to data_resets_path, alert: t("resets.confirm_exact") unless params[:confirmation] == required
    reset = current_user.data_resets.create!(scope: scope, cutoff_at: Time.current)
    audit!("test_data.reset_requested", reset, details: { scope: scope }) if current_user.admin?
    DataResetJob.perform_later(reset.id)
    redirect_to data_reset_path(reset), notice: t("resets.queued")
  rescue Auth::RateLimiter::Limited
    render_rate_limited
  rescue ActiveJob::EnqueueError
    reset&.update!(status: "failed", error_code: "queue_unavailable", finished_at: Time.current)
    redirect_to data_resets_path, alert: t("resets.queue_unavailable")
  end
end
