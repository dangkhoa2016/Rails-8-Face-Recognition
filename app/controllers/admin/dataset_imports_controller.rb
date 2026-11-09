module Admin
  class DatasetImportsController < BaseController
    def index
      @imports = DatasetImport.order(created_at: :desc).limit(100)
    end

    def new
      @dataset_import = DatasetImport.new(source_name: "CompactFaces Synthetic Face Dataset", dataset_version: "1.0.0",
        source_url: "https://huggingface.co/datasets/dangkhoa2016/compactfaces-synthetic-face-dataset")
    end

    def create
      attrs = params.require(:dataset_import).permit(:source_name, :source_url, :dataset_version)
      @dataset_import = DatasetImport.find_or_initialize_by(source_url: attrs.fetch(:source_url), dataset_version: attrs.fetch(:dataset_version))
      if @dataset_import.new_record?
        @dataset_import.assign_attributes(attrs)
        @dataset_import.import_status = "pending"
        @dataset_import.save!
      end
      audit!("dataset_import.created", @dataset_import)
      redirect_to admin_dataset_import_path(@dataset_import), notice: helpers.ui("Import registered. Validate the local dataset snapshot before importing.")
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    end

    def show
      @dataset_import = DatasetImport.find(params[:id])
      @counts = @dataset_import.face_images.group(:collection, :role).count
      @root_path = ENV["DATASET_IMPORT_ROOT"].presence
      @metadata_ready = DatasetImports::VerifiedSnapshot.metadata_file(@root_path).present?
    end

    def verify_and_import
      item = DatasetImport.find(params[:id])
      unless item.import_status.in?(%w[pending failed completed])
        return redirect_to admin_dataset_import_path(item), alert: helpers.ui("Import is already running.")
      end
      unless DatasetImports::VerifiedSnapshot.metadata_file(ENV["DATASET_IMPORT_ROOT"]).present?
        return redirect_to admin_dataset_import_path(item),
          alert: I18n.t("dataset_setup.metadata_missing")
      end
      item.update!(import_status: "verifying", error_summary: nil, started_at: Time.current)
      begin
        DatasetImportJob.perform_later(item.id)
      rescue StandardError => error
        item.update!(import_status: "failed", finished_at: Time.current,
          error_summary: "Background queue unavailable; retry after the worker is running.")
        Rails.logger.error("Dataset enqueue failed category=#{error.class.name} import_id=#{item.id}")
        return redirect_to admin_dataset_import_path(item), alert: helpers.ui("Background queue unavailable; import was not scheduled.")
      end
      audit!("dataset_import.queued", item)
      redirect_to admin_dataset_import_path(item), notice: helpers.ui("Dataset verification queued.")
    end
  end
end
