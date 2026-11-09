module Admin
  class UnknownTestsController < BaseController
    before_action :load_image, only: [:show, :destroy]

    def index
      @images = FaceImage.where(collection: "admin", role: "submission").includes(:owner_user).order(created_at: :desc).limit(100)
    end

    def new; end

    def create
      Auth::RateLimiter.consume!(action: :unknown_test, email: current_user.email, ip: request.remote_ip)
      image = Submissions::Create.call(user: current_user, upload: params[:image], consent: params[:consent],
        admin_unknown: true, provenance_note: params[:provenance_note])
      audit!("unknown_test.created", image)
      redirect_to admin_unknown_test_path(image), notice: helpers.ui("Unknown test saved as asserted_unknown, not a verified false positive.")
    rescue Auth::RateLimiter::Limited
      render_rate_limited
    rescue Submissions::Create::InvalidUpload => error
      @error_message = error.message
      render :new, status: :unprocessable_entity
    end

    def show
      @attempts = @image.recognition_attempts.includes(:result_identity).order(created_at: :desc).limit(20)
    end

    def destroy
      audit!("unknown_test.deleted", @image)
      Submissions::Purge.call(@image)
      redirect_to admin_unknown_tests_path, notice: helpers.ui("Unknown-test data deleted.")
    end

    private

    def load_image
      @image = FaceImage.where(collection: "admin", role: "submission").find(params[:id])
    end
  end
end
