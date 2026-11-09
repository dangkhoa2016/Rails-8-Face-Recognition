class RecognizeFaceJob < ApplicationJob
  queue_as :default
  retry_on Embeddings::Ensure::Busy, wait: 20.seconds, attempts: 10

  def perform(attempt_id)
    attempt = RecognitionAttempt.includes(:query_face_image, :embedding_profile, :recognition_policy).find_by(id: attempt_id)
    return unless attempt && attempt.decision == "pending"

    # A policy can be retired, or the gallery can change, between enqueue and execution.
    # Never turn that situation into a stale biometric identification assertion.
    unless attempt.embedding_profile.coverage_complete? &&
           attempt.recognition_policy&.status == "approved" &&
           attempt.recognition_policy.embedding_profile_id == attempt.embedding_profile_id
      attempt.update!(decision: "indeterminate", error_code: "policy_or_gallery_unavailable")
      return
    end

    embedding = Embeddings::Ensure.call(image: attempt.query_face_image, profile: attempt.embedding_profile)
    result = Recognition::Decide.call(embedding: embedding, profile: attempt.embedding_profile, policy: attempt.recognition_policy)
    attempt.update!(decision: result.decision, result_identity: result.identity, top_similarity: result.score)
  rescue Embeddings::Ensure::Busy
    raise # ActiveJob performs the bounded retry, not a fabricated recognition result.
  rescue Embeddings::Client::Error => error
    attempt&.update!(decision: "failed", error_code: error.code) if attempt&.decision == "pending"
  rescue StandardError => error
    attempt&.update!(decision: "failed", error_code: "internal_error") if attempt&.decision == "pending"
    Rails.logger.error("Recognition job failed category=#{error.class.name} attempt_id=#{attempt_id}")
  end
end
