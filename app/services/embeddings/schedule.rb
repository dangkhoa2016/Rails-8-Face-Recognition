module Embeddings
  class Schedule
    def self.call(image:, profile:)
      return :cached if FaceEmbedding.exists?(face_image: image, embedding_profile: profile)
      return :expired if image.storage_policy == "transient" && image.expires_at <= Time.current

      created = false
      begin
        req = EmbeddingRequest.create!(face_image: image, embedding_profile: profile)
        created = true
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        req = EmbeddingRequest.find_by!(face_image: image, embedding_profile: profile)
      end

      unless created
        requeued = false
        req.with_lock do
          return :cached if FaceEmbedding.exists?(face_image: image, embedding_profile: profile)
          # Re-read the lease under the row lock, never reset a fresh in-flight worker.
          abandoned = req.status == "processing" && req.lease_expires_at&.past?
          unqueued = req.status == "pending" && req.updated_at < 5.minutes.ago
          missing_completed_record = req.status == "completed"
          if req.status == "failed" || abandoned || unqueued || missing_completed_record
            req.update!(status: "pending", lease_expires_at: nil, error_code: nil)
            requeued = true
          end
        end
        return :in_progress unless requeued
      end

      EmbeddingGenerationJob.perform_later(req.id)
      :queued
    end
  end
end
