class EmbeddingProfile < ApplicationRecord
  STATUSES = %w[draft preparing ready deprecated error].freeze
  IMMUTABLE_FIELDS = %w[embedding_model_id dimension model_revision preprocessing_version instruction request_config_digest].freeze

  belongs_to :embedding_model
  has_many :face_embeddings, dependent: :restrict_with_exception
  has_many :embedding_requests, dependent: :restrict_with_exception
  has_many :recognition_policies, dependent: :restrict_with_exception

  validates :status, inclusion: { in: STATUSES }
  validates :dimension, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 4096 }
  validates :model_revision, format: { with: /\A[0-9a-f]{40,64}\z/ }
  validates :preprocessing_version, presence: true
  validates :request_config_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :instruction, length: { maximum: 512 }, allow_nil: true
  validates :config_sha256, format: { with: /\A[0-9a-f]{64}\z/ }, allow_nil: true
  validates :instruction_sha256, format: { with: /\A[0-9a-f]{64}\z/ }, allow_nil: true
  validate :model_supports_configuration
  validate :lock_config_after_use, on: :update

  def required_enrollments
    FaceImage.enrollment_core.count
  end

  def available_enrollments
    FaceEmbedding.where(embedding_profile_id: id, face_image_id: FaceImage.enrollment_core.select(:id)).count
  end

  def missing_enrollment_images
    FaceImage.enrollment_core.where.not(id: FaceEmbedding.where(embedding_profile_id: id).select(:face_image_id))
  end

  def coverage_complete?
    required_enrollments == 120 && Identity.active.count == 120 &&
      missing_enrollment_images.none? && status == "ready"
  end

  def approved_policy
    recognition_policies.where(status: "approved").order(approved_at: :desc).first
  end

  private

  def model_supports_configuration
    return if embedding_model.nil?
    errors.add(:dimension, "unsupported by model") unless embedding_model.supports_dimension?(dimension)
    if instruction.present? && !embedding_model.accepts_instruction?
      errors.add(:instruction, "is not supported by this model")
    end
  end

  def lock_config_after_use
    return unless persisted? && (face_embeddings.exists? || status_in_database != "draft")
    IMMUTABLE_FIELDS.each do |field|
      errors.add(field, "cannot change after profile has been used") if will_save_change_to_attribute?(field)
    end
  end
end
