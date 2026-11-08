class RecognitionAttempt < ApplicationRecord
  DECISIONS = %w[pending matched unknown indeterminate failed].freeze
  belongs_to :user
  belongs_to :query_face_image, class_name: "FaceImage"
  belongs_to :embedding_profile
  belongs_to :recognition_policy, optional: true
  belongs_to :result_identity, class_name: "Identity", optional: true
  validates :decision, inclusion: { in: DECISIONS }
  validates :top_similarity, numericality: { greater_than_or_equal_to: -1, less_than_or_equal_to: 1 }, allow_nil: true
  validate :policy_snapshot_consistent
  validate :ownership_consistent

  private

  def ownership_consistent
    return unless user && query_face_image
    if query_face_image.role == "submission" && query_face_image.owner_user_id != user_id
      errors.add(:query_face_image, "must belong to this user")
    end
  end

  def policy_snapshot_consistent
    if recognition_policy && recognition_policy.embedding_profile_id != embedding_profile_id
      errors.add(:recognition_policy, "must match the snapshotted profile")
    end
  end
end
