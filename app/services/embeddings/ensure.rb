module Embeddings
  class Ensure
    class Busy < StandardError; end

    def self.call(image:, profile:)
      # Do not reuse a cached biometric vector after the query image has expired.
      raise Client::Error, "expired_image" if image.storage_policy == "transient" && image.expires_at <= Time.current
      cached = FaceEmbedding.find_by(face_image: image, embedding_profile: profile)
      return cached if cached
      raise Client::Error, "unprepared_profile" unless profile.status.in?(%w[preparing ready]) && profile.config_sha256.present?
      raise Client::Error, "missing_image" unless image.image.attached?
      req = EmbeddingRequest.create_or_find_by!(face_image: image, embedding_profile: profile)
      claimed = false
      req.with_lock do
        cached = FaceEmbedding.find_by(face_image: image, embedding_profile: profile)
        return cached if cached
        if req.status != "processing" || req.lease_expires_at.blank? || req.lease_expires_at <= Time.current
          req.update!(status: "processing", lease_expires_at: 11.minutes.from_now, attempt_count: req.attempt_count + 1, error_code: nil)
          claimed = true
        end
      end
      raise Busy, "Embedding request is already being processed" unless claimed

      bytes = image.image.blob.download
      raise Client::Error, "image_digest_mismatch" unless Digest::SHA256.hexdigest(bytes) == image.original_sha256
      result = Client.new(profile.embedding_model.inference_service).embed(image_bytes: bytes, profile: profile)
      embedding = FaceEmbedding.find_or_create_by!(face_image: image, embedding_profile: profile) do |record|
        record.embedding = result.fetch("vector")
        record.input_sha256 = result.fetch("input_sha256")
        record.config_sha256 = result.fetch("embedding_metadata").fetch("config_sha256")
        record.normalized = true
        record.elapsed_ms = result["elapsed_ms"]
      end
      req.update!(status: "completed", lease_expires_at: nil, error_code: nil)
      if profile.missing_enrollment_images.none? && profile.status == "preparing" && FaceImage.enrollment_core.count == 120
        profile.update!(status: "ready")
      end
      embedding
    rescue Client::Error => error
      req&.update!(status: "failed", lease_expires_at: nil, error_code: error.code) if claimed
      raise
    rescue StandardError
      req&.update!(status: "failed", lease_expires_at: nil, error_code: "internal_error") if claimed
      raise
    end
  end
end
