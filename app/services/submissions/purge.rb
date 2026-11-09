module Submissions
  class Purge
    def self.call(image)
      raise ArgumentError, "Only transient submissions may be purged" unless image.role == "submission" && image.storage_policy == "transient"
      FaceImage.transaction do
        image.recognition_attempts.delete_all
        image.embedding_requests.delete_all
        image.face_embeddings.delete_all
        image.destroy!
      end
      # has_one_attached uses purge_later after destroy; no reference assets are touched.
    end
  end
end
