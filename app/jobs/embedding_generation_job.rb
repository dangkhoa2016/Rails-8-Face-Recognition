class EmbeddingGenerationJob < ApplicationJob
  queue_as :default
  retry_on Embeddings::Ensure::Busy, wait: 20.seconds, attempts: 8

  def perform(request_id)
    request = EmbeddingRequest.includes(:face_image, :embedding_profile).find_by(id: request_id)
    return unless request
    return if FaceEmbedding.exists?(face_image_id: request.face_image_id, embedding_profile_id: request.embedding_profile_id)
    Embeddings::Ensure.call(image: request.face_image, profile: request.embedding_profile)
  rescue Embeddings::Client::Error => error
    Rails.logger.warn("Embedding generation failed code=#{error.code} request_id=#{request_id}")
  end
end
