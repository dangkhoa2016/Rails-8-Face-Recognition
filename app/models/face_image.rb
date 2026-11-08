class FaceImage < ApplicationRecord
  COLLECTIONS = %w[core additional admin user].freeze
  ROLES = %w[enrollment sample_probe submission].freeze
  SLOTS = %w[SOURCE P1 P2 E1 E2].freeze

  belongs_to :identity, optional: true
  belongs_to :dataset_import, optional: true
  belongs_to :owner_user, class_name: "User", optional: true
  has_many :face_embeddings, dependent: :restrict_with_exception
  has_many :embedding_requests, dependent: :restrict_with_exception
  has_many :recognition_attempts, foreign_key: :query_face_image_id, dependent: :restrict_with_exception
  has_one_attached :image, service: ->(record) {
    if Rails.env.production?
      record.storage_policy == "reference" ? :r2_reference : :r2_submissions
    elsif Rails.env.test?
      :test
    else
      :local
    end
  }

  validates :collection, inclusion: { in: COLLECTIONS }
  validates :role, inclusion: { in: ROLES }
  validates :slot, inclusion: { in: SLOTS }, allow_nil: true
  validates :original_sha256, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :storage_policy, inclusion: { in: %w[reference transient] }
  validates :ground_truth_label, inclusion: { in: %w[asserted_unknown verified_unknown] }, allow_nil: true
  validates :provenance_note, length: { maximum: 2000 }, allow_nil: true
  validate :collection_membership
  validate :transient_owner_and_expiry
  validate :image_bytes_immutable, on: :update

  scope :enrollment_core, -> { joins(:identity).merge(Identity.active).where(collection: "core", role: "enrollment", slot: "SOURCE") }
  scope :sample_probes, -> { where(role: "sample_probe") }
  scope :expirable_submissions, -> { where(role: "submission", storage_policy: "transient").where("expires_at <= ?", Time.current) }

  private

  def collection_membership
    if role == "enrollment" && (collection != "core" || slot != "SOURCE" || identity_id.nil?)
      errors.add(:role, "requires a Core SOURCE image linked to a Core identity")
    end
    if collection == "additional" && identity_id.present?
      errors.add(:identity, "cannot enroll Additional identities")
    end
    if ground_truth_label.present? && collection != "admin"
      errors.add(:ground_truth_label, "is only available for admin submissions")
    end
    if %w[admin user].include?(collection) && (identity_id.present? || role != "submission")
      errors.add(:role, "uploads must be submissions without known identity")
    end
  end

  def transient_owner_and_expiry
    return unless storage_policy == "transient"
    errors.add(:expires_at, "is required") if expires_at.blank?
    errors.add(:owner_user, "is required") if owner_user_id.blank?
  end

  def image_bytes_immutable
    if will_save_change_to_original_sha256? ||
       (will_save_change_to_inference_input_sha256? && inference_input_sha256_in_database.present?)
      errors.add(:base, "Image checksums are immutable; insert a new FaceImage")
    end
  end
end
