module Submissions
  # Deliberately never touches reference images, SOURCE enrollments, Core
  # identities, profiles, policies, providers, or persistent reference vectors.
  # Each reset is a snapshot with a cutoff to avoid deleting later uploads.
  class ResetTestData
    def self.call(reset)
      raise ArgumentError, "admin privileges required" if reset.scope != "mine" && !(reset.actor.admin? && reset.actor.enabled? && reset.actor.verified?)
      actor = reset.actor
      if reset.scope == "probe_cache"
        # Deletes query-only cache rows, never Core SOURCE enrollment rows.
        probe_ids = FaceImage.sample_probes.where("created_at <= ?", reset.cutoff_at).select(:id)
        attempts_count = RecognitionAttempt.where(query_face_image_id: probe_ids).where("created_at <= ?", reset.cutoff_at).delete_all
        embedding_count = FaceEmbedding.where(face_image_id: probe_ids).where("created_at <= ?", reset.cutoff_at).delete_all
        requests_count = EmbeddingRequest.where(face_image_id: probe_ids).where("created_at <= ?", reset.cutoff_at).delete_all
        reset.increment!(:deleted_attempts, attempts_count)
        reset.increment!(:deleted_embeddings, embedding_count)
        reset.increment!(:deleted_embedding_requests, requests_count)
        return
      end
      images = FaceImage.where(role: "submission", storage_policy: "transient").where("created_at <= ?", reset.cutoff_at)
      images = images.where(owner_user_id: actor.id) if reset.scope == "mine"
      image_ids = images.pluck(:id)
      # Purge each image via the canonical privacy-safe service.
      image_ids.each do |image_id|
        image = FaceImage.find_by(id: image_id)
        next unless image
        Submissions::Purge.call(image)
        reset.increment!(:deleted_submissions)
      end

      attempts = RecognitionAttempt.where("created_at <= ?", reset.cutoff_at)
      attempts = attempts.where(user_id: actor.id) if reset.scope == "mine"
      count = attempts.delete_all
      reset.increment!(:deleted_attempts, count)
    end
  end
end
