class SamplesController < ApplicationController
  def index
    @collection = params[:collection].presence_in(%w[core additional])
    @slot = params[:slot].presence_in(%w[P1 P2 E1 E2])
    @samples = FaceImage.sample_probes.where(collection: %w[core additional]).includes(:identity, image_attachment: :blob)
    @samples = @samples.where(collection: @collection) if @collection
    @samples = @samples.where(slot: @slot) if @slot
    @total = @samples.count
    @page = [[params[:page].to_i, 1].max, 10_000].min
    @samples = @samples.order(:collection, :dataset_identity_key, :slot).limit(24).offset((@page - 1) * 24)
  end

  def show
    @sample = FaceImage.sample_probes.where(collection: %w[core additional]).find(params[:id])
  end
end
