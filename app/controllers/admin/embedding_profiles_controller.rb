module Admin
  class EmbeddingProfilesController < BaseController
    before_action :load_profile, only: [:show, :preflight, :generate_missing, :activate]

    def index
      @profiles = EmbeddingProfile.includes(:embedding_model).order(created_at: :desc)
      @active_profile_id = ApplicationSetting.current.active_recognition_profile_id
    end

    def show
      @requests = @profile.embedding_requests.group(:status).count
      @policy = @profile.approved_policy
      @active = ApplicationSetting.current.active_recognition_profile_id == @profile.id
    end

    def new
      @models = EmbeddingModel.where(enabled: true).includes(:inference_service)
    end

    def create
      model = EmbeddingModel.where(enabled: true).find(params.require(:embedding_model_id))
      @profile = EmbeddingProfiles::Create.call(
        model: model, dimension: params.require(:dimension), model_revision: params.require(:model_revision),
        preprocessing_version: params.require(:preprocessing_version), instruction: params[:instruction]
      )
      audit!("embedding_profile.selected", @profile)
      redirect_to admin_embedding_profile_path(@profile), notice: helpers.ui("Existing profile reused if exact configuration matched. No embeddings were removed.")
    rescue ActiveRecord::RecordInvalid, ArgumentError => error
      @models = EmbeddingModel.where(enabled: true).includes(:inference_service)
      @error_message = error.message
      render :new, status: :unprocessable_entity
    end

    def preflight
      unless @profile.status.in?(%w[draft error]) && @profile.config_sha256.blank? && @profile.embedding_model.enabled? && @profile.embedding_model.inference_service.enabled?
        return redirect_to admin_embedding_profile_path(@profile), alert: helpers.ui("Preflight requires a draft profile with enabled model and service.")
      end
      queued = false
      @profile.with_lock do
        if @profile.status.in?(%w[draft error]) && @profile.config_sha256.blank?
          @profile.update!(status: "preparing")
          queued = true
        end
      end
      return redirect_to admin_embedding_profile_path(@profile), alert: helpers.ui("Preflight is already underway.") unless queued
      begin
        ProfilePreflightJob.perform_later(@profile.id)
      rescue StandardError => error
        @profile.update!(status: "error")
        Rails.logger.error("Preflight enqueue failed category=#{error.class.name} profile_id=#{@profile.id}")
        return redirect_to admin_embedding_profile_path(@profile), alert: helpers.ui("Background queue unavailable; preflight was not scheduled.")
      end
      audit!("embedding_profile.preflight_queued", @profile)
      redirect_to admin_embedding_profile_path(@profile), notice: helpers.ui("Preflight queued using one authorized Core SOURCE image.")
    end

    def generate_missing
      unless @profile.status.in?(%w[preparing ready]) && @profile.config_sha256.present?
        return redirect_to admin_embedding_profile_path(@profile), alert: helpers.ui("A successful preflight is required first.")
      end
      missing = @profile.missing_enrollment_images.where(id: FaceImage.joins(:image_attachment).select(:id)).limit(120)
      count = missing.count
      missing.find_each { |image| Embeddings::Schedule.call(image: image, profile: @profile) }
      audit!("embedding_profile.missing_queued", @profile, details: { count: count })
      redirect_to admin_embedding_profile_path(@profile), notice: "Scheduled #{count} missing enrollment images; existing embeddings were reused."
    end

    def activate
      ApplicationSetting.current.activate!(profile: @profile, policy: @profile.approved_policy, actor: current_user)
      redirect_to admin_embedding_profile_path(@profile), notice: helpers.ui("Active profile changed. All other embeddings remain intact.")
    rescue ArgumentError => error
      redirect_to admin_embedding_profile_path(@profile), alert: error.message
    end

    def deactivate
      ApplicationSetting.current.deactivate!(actor: current_user)
      redirect_to admin_embedding_profiles_path, notice: helpers.ui("Recognition deactivated; embedding caches remain available.")
    end

    private

    def load_profile
      @profile = EmbeddingProfile.includes(embedding_model: :inference_service).find(params[:id])
    end
  end
end
