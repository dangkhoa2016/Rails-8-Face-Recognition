class SubmissionsController < ApplicationController
  before_action :set_submission, only: [:show, :destroy]

  def index
    @submissions = current_user.owned_face_images.where(role: "submission").order(created_at: :desc).limit(100)
  end

  def new; end

  def create
    Auth::RateLimiter.consume!(action: :upload, email: current_user.email, ip: request.remote_ip)
    image = Submissions::Create.call(user: current_user, upload: params[:image],
                                     consent: params[:consent], admin_unknown: false)
    redirect_to submission_path(image), notice: helpers.ui("Private image uploaded. Nothing is enrolled automatically.")
  rescue Auth::RateLimiter::Limited
    render_rate_limited
  rescue Submissions::Create::InvalidUpload => error
    @error_message = error.message
    render :new, status: :unprocessable_entity
  end

  def show
    @attempts = current_user.recognition_attempts.where(query_face_image: @submission).order(created_at: :desc).limit(10)
  end

  def destroy
    Submissions::Purge.call(@submission)
    redirect_to submissions_path, notice: helpers.ui("Submission and its stored recognition data were deleted.")
  end

  private

  def set_submission
    @submission = current_user.owned_face_images.where(role: "submission").find(params[:id])
  end
end
