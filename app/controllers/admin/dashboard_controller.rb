module Admin
  class DashboardController < BaseController
    def index
      @identities = Identity.active.count
      @enrolled = FaceImage.enrollment_core.count
      @samples = FaceImage.sample_probes.count
      @profiles = EmbeddingProfile.includes(:embedding_model).order(created_at: :desc).limit(6)
      @setting = ApplicationSetting.current
      @failures = EmbeddingRequest.where(status: "failed").count
      @pending = EmbeddingRequest.where(status: %w[pending processing]).count
      @attempts = RecognitionAttempt.includes(:user).order(created_at: :desc).limit(8)
      @imports = DatasetImport.order(created_at: :desc).limit(3)
    end
  end
end
