class RecognitionAttemptsController < ApplicationController
  before_action :load_attempt, only: [:show, :destroy]

  def index
    @attempts = current_user.recognition_attempts.includes(:embedding_profile, :result_identity).order(created_at: :desc).limit(100)
  end

  def new
    @sample = FaceImage.sample_probes.where(collection: %w[core additional]).find_by(id: params[:sample_id]) if params[:sample_id].present?
    @submissions = current_user.owned_face_images.where(role: "submission").where("expires_at > ?", Time.current).order(created_at: :desc).limit(50)
    @setting = ApplicationSetting.current
  end

  def create
    Auth::RateLimiter.consume!(action: :recognition, email: current_user.email, ip: request.remote_ip)
    image = FaceImage.find(params.require(:face_image_id))
    unless image.role == "sample_probe" && %w[core additional].include?(image.collection) ||
           image.role == "submission" && image.owner_user_id == current_user.id && image.expires_at&.future?
      return head :not_found
    end
    unless image.image.attached?
      return redirect_to new_recognition_attempt_path, alert: helpers.ui("This image is not available.")
    end
    setting = ApplicationSetting.current
    unless setting.active_recognition_profile&.coverage_complete? && setting.active_recognition_policy&.status == "approved"
      return redirect_to new_recognition_attempt_path, alert: helpers.ui("Recognition is unavailable until calibration and enrollment approval.")
    end
    attempt = current_user.recognition_attempts.create!(query_face_image: image,
      embedding_profile: setting.active_recognition_profile, recognition_policy: setting.active_recognition_policy,
      decision: "pending", expires_at: 30.days.from_now)
    begin
      RecognizeFaceJob.perform_later(attempt.id)
    rescue StandardError => error
      attempt.update!(decision: "failed", error_code: "queue_unavailable")
      Rails.logger.error("Recognition enqueue failed category=#{error.class.name} attempt_id=#{attempt.id}")
      return redirect_to recognition_attempt_path(attempt), alert: helpers.ui("The background queue is unavailable; no inference request was scheduled.")
    end
    redirect_to recognition_attempt_path(attempt), notice: helpers.ui("Recognition request queued.")
  rescue Auth::RateLimiter::Limited
    render_rate_limited
  end

  def show
    @sample = @attempt.query_face_image
    @can_view_image = @sample.role == "sample_probe" || @sample.owner_user_id == current_user.id
  end

  def destroy
    @attempt.destroy!
    redirect_to recognition_attempts_path, notice: helpers.ui("Recognition result removed.")
  end

  private

  def load_attempt
    @attempt = current_user.recognition_attempts.includes(:embedding_profile, :recognition_policy, :result_identity, :query_face_image).find(params[:id])
  end
end
