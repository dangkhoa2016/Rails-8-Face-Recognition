class FaceEmbedding < ApplicationRecord
  belongs_to :face_image
  belongs_to :embedding_profile
  validates :face_image_id, uniqueness: { scope: :embedding_profile_id }
  validates :input_sha256, :config_sha256, format: { with: /\A[0-9a-f]{64}\z/ }
  validate :matches_pinned_profile
  validate :valid_normalized_vector
  before_update :prevent_mutation

  private

  def matches_pinned_profile
    return if embedding_profile.nil? || face_image.nil?
    errors.add(:config_sha256, "does not match profile") if config_sha256 != embedding_profile.config_sha256 || config_sha256.blank?
    if face_image.inference_input_sha256.blank? || input_sha256 != face_image.inference_input_sha256
      errors.add(:input_sha256, "does not match image input")
    end
    errors.add(:normalized, "is required") unless normalized == true
  end

  def valid_normalized_vector
    return if embedding.nil? || embedding_profile.nil?
    values = embedding.respond_to?(:to_a) ? embedding.to_a : Array(embedding)
    if values.length != embedding_profile.dimension || !values.all? { |x| x.is_a?(Numeric) && x.finite? }
      errors.add(:embedding, "must contain exactly #{embedding_profile.dimension} finite values")
      return
    end
    norm = Math.sqrt(values.sum { |x| x.to_f**2 })
    errors.add(:embedding, "must be L2-normalized") unless (norm - 1.0).abs <= 0.01
  end

  def prevent_mutation
    errors.add(:base, "Embeddings are immutable")
    throw :abort
  end
end
