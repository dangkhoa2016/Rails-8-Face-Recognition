class EmbeddingRequest < ApplicationRecord
  STATUSES = %w[pending processing completed failed].freeze
  belongs_to :face_image
  belongs_to :embedding_profile
  validates :status, inclusion: { in: STATUSES }
  validates :face_image_id, uniqueness: { scope: :embedding_profile_id }
  validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
