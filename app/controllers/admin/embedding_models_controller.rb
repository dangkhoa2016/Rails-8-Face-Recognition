module Admin
  class EmbeddingModelsController < BaseController
    before_action :load_model, only: [:edit, :update]

    def index
      @models = EmbeddingModel.includes(:inference_service).order(:display_name)
    end

    def new
      @model = EmbeddingModel.new(enabled: false, supported_dimensions: [1024, 2048, 4096])
      load_services
    end

    def create
      @model = EmbeddingModel.new(model_params)
      @model.supported_dimensions = parse_dimensions!
      @model.save!
      audit!("embedding_model.created", @model)
      redirect_to admin_embedding_models_path, notice: helpers.ui("Model saved. Validate capabilities against live /v1/models before enabling.")
    rescue ActiveRecord::RecordInvalid, ArgumentError, JSON::ParserError => error
      @error_message = error.message
      load_services
      render :new, status: :unprocessable_entity
    end

    def edit
      load_services
    end

    def update
      @model.assign_attributes(model_params)
      @model.supported_dimensions = parse_dimensions!
      @model.save!
      audit!("embedding_model.updated", @model, details: { enabled: @model.enabled? })
      redirect_to admin_embedding_models_path, notice: helpers.ui("Model updated. Existing profiles retain their pinned identity.")
    rescue ActiveRecord::RecordInvalid, ArgumentError, JSON::ParserError => error
      @error_message = error.message
      load_services
      render :edit, status: :unprocessable_entity
    end

    private

    def load_model
      @model = EmbeddingModel.find(params[:id])
    end

    def load_services
      @services = InferenceService.order(:name)
    end

    def model_params
      params.require(:embedding_model).permit(:inference_service_id, :api_model_id, :display_name, :repository_name, :enabled)
    end

    def parse_dimensions!
      dims = JSON.parse(params.require(:supported_dimensions_json).to_s)
      raise ArgumentError, "Dimensions must be an array or a min/max JSON object" unless dims.is_a?(Array) || dims.is_a?(Hash)
      dims
    end
  end
end
