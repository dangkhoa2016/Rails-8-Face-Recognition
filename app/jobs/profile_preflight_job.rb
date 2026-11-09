class ProfilePreflightJob < ApplicationJob
  queue_as :default

  def perform(profile_id)
    profile = EmbeddingProfile.includes(embedding_model: :inference_service).find(profile_id)
    return unless profile.status == "preparing" && profile.config_sha256.blank?
    image = FaceImage.enrollment_core.joins(:image_attachment).first
    raise Embeddings::Client::Error, "no_enrollment_image" unless image
    bytes = image.image.blob.download
    raise Embeddings::Client::Error, "image_digest_mismatch" unless Digest::SHA256.hexdigest(bytes) == image.original_sha256
    result = Embeddings::Client.new(profile.embedding_model.inference_service).embed(image_bytes: bytes, profile: profile)
    metadata = result.fetch("embedding_metadata")
    profile.with_lock do
      if profile.config_sha256.present? && profile.config_sha256 != metadata.fetch("config_sha256")
        raise Embeddings::Client::Error, "configuration_drift"
      end
      profile.update!(config_sha256: metadata.fetch("config_sha256"), instruction_sha256: metadata["instruction_sha256"], status: "preparing")
    end
    FaceEmbedding.find_or_create_by!(face_image: image, embedding_profile: profile) do |record|
      record.embedding = result.fetch("vector")
      record.input_sha256 = result.fetch("input_sha256")
      record.config_sha256 = metadata.fetch("config_sha256")
      record.normalized = true
      record.elapsed_ms = result["elapsed_ms"]
    end
  rescue Embeddings::Client::Error => error
    profile&.update!(status: "error") if profile&.status == "preparing" && profile&.config_sha256.blank?
    Rails.logger.warn("Profile preflight failed code=#{error.code} profile_id=#{profile_id}")
  rescue StandardError => error
    profile&.update!(status: "error") if profile&.status == "preparing" && profile&.config_sha256.blank?
    Rails.logger.error("Profile preflight failed category=#{error.class.name} profile_id=#{profile_id}")
  end
end
