class DataResetJob < ApplicationJob
  queue_as :default

  def perform(reset_id)
    reset = DataReset.find_by(id: reset_id)
    return unless reset
    reset.with_lock do
      return unless reset.status == "pending"
      reset.update!(status: "running", started_at: Time.current)
    end
    Submissions::ResetTestData.call(reset)
    reset.update!(status: "completed", finished_at: Time.current)
    if reset.actor.admin?
      AdminAuditEvent.create!(actor: reset.actor, action: "test_data.reset_completed",
        subject_type: "DataReset", subject_id: reset.id,
        details: { scope: reset.scope, submissions: reset.deleted_submissions, attempts: reset.deleted_attempts,
          embeddings: reset.deleted_embeddings, embedding_requests: reset.deleted_embedding_requests })
    end
  rescue StandardError => error
    reset&.update!(status: "failed", error_code: "reset_failed", finished_at: Time.current)
    Rails.logger.error("Data reset failed reset_id=#{reset_id} class=#{error.class.name}")
  end
end
