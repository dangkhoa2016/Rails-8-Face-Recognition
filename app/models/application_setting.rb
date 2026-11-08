class ApplicationSetting < ApplicationRecord
  belongs_to :active_recognition_profile, class_name: "EmbeddingProfile", optional: true
  belongs_to :active_recognition_policy, class_name: "RecognitionPolicy", optional: true
  belongs_to :activated_by, class_name: "User", optional: true

  def self.current
    find_or_create_by!(id: 1)
  end

  def deactivate!(actor:)
    raise ArgumentError, "admin required" unless actor&.admin?
    with_lock do
      update!(active_recognition_profile: nil, active_recognition_policy: nil, activated_by: actor, activated_at: Time.current)
      AdminAuditEvent.create!(actor: actor, action: "profile.deactivated", subject_type: "ApplicationSetting", subject_id: id)
    end
  end

  def activate!(profile:, policy:, actor:)
    raise ArgumentError, "admin required" unless actor&.admin?
    with_lock do
      raise ArgumentError, "profile is not fully prepared" unless profile.coverage_complete?
      unless profile.embedding_model.enabled? && profile.embedding_model.inference_service.enabled? && profile.embedding_model.inference_service.secret_available?
        raise ArgumentError, "enabled model, service and server-side secret are required"
      end
      raise ArgumentError, "approved policy for the exact profile required" unless policy&.status == "approved" && policy.embedding_profile_id == profile.id
      update!(active_recognition_profile: profile, active_recognition_policy: policy, activated_by: actor, activated_at: Time.current)
      AdminAuditEvent.create!(actor: actor, action: "profile.activated", subject_type: "EmbeddingProfile", subject_id: profile.id, details: { policy_id: policy.id })
    end
  end
end
