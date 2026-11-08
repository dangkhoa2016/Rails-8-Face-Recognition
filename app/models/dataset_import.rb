class DatasetImport < ApplicationRecord
  STATUSES = %w[pending verifying importing completed failed].freeze
  has_many :face_images, dependent: :restrict_with_exception
  validates :source_name, :source_url, :dataset_version, presence: true
  validates :import_status, inclusion: { in: STATUSES }
  validates :manifest_sha256, format: { with: /\A[0-9a-f]{64}\z/ }, allow_nil: true
end
