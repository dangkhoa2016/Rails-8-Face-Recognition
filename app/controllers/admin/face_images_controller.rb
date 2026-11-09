module Admin
  class FaceImagesController < BaseController
    def index
      @collection = params[:collection].presence_in(FaceImage::COLLECTIONS)
      @role = params[:role].presence_in(FaceImage::ROLES)
      @images = FaceImage.includes(:identity).order(created_at: :desc)
      @images = @images.where(collection: @collection) if @collection
      @images = @images.where(role: @role) if @role
      @total = @images.count
      @page = [[params[:page].to_i, 1].max, 10_000].min
      @images = @images.limit(40).offset((@page - 1) * 40)
    end

    def show
      @image = FaceImage.find(params[:id])
      @embeddings = @image.face_embeddings.includes(embedding_profile: :embedding_model).order(created_at: :desc)
    end
  end
end
