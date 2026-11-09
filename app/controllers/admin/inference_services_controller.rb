module Admin
  class InferenceServicesController < BaseController
    before_action :load_service, only: [:edit, :update, :check_connection]

    def index
      @services = InferenceService.includes(:embedding_models).order(:name)
    end

    def new
      @service = InferenceService.new(enabled: false, request_timeout_seconds: 300)
    end

    def create
      @service = InferenceService.new(service_params)
      @service.save!
      audit!("inference_service.created", @service, details: { name: @service.name })
      redirect_to admin_inference_services_path, notice: helpers.ui("Inference service saved. Secrets stay in the server environment.")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      @service.update!(service_params)
      audit!("inference_service.updated", @service, details: { enabled: @service.enabled? })
      redirect_to admin_inference_services_path, notice: helpers.ui("Inference service updated.")
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    def check_connection
      metadata = Embeddings::Client.new(@service).models
      @service.update!(enabled: true) if !@service.enabled? && params[:enable_after_check] == "1"
      audit!("inference_service.checked", @service)
      redirect_to admin_inference_services_path, notice: "Gateway returned #{Array(metadata["models"]).length} model entries. Review model revisions separately."
    rescue Embeddings::Client::Error => error
      redirect_to admin_inference_services_path, alert: "Gateway check failed (#{error.code})."
    end

    private

    def load_service
      @service = InferenceService.find(params[:id])
    end

    def service_params
      params.require(:inference_service).permit(:name, :base_url, :auth_secret_reference, :enabled, :request_timeout_seconds)
    end
  end
end
