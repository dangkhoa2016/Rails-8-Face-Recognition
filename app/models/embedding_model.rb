class EmbeddingModel < ApplicationRecord
  belongs_to :inference_service
  has_many :embedding_profiles, dependent: :restrict_with_exception
  validates :api_model_id, :display_name, :repository_name, presence: true
  validates :api_model_id, uniqueness: { scope: :inference_service_id }
  validate :dimensions_are_valid
  validate :preserve_api_identity_after_profile_creation, on: :update

  def supports_dimension?(dimension)
    dims = supported_dimensions
    case dims
    when Array then dims.map(&:to_i).include?(dimension.to_i)
    when Hash then dimension.to_i.between?(dims.fetch("min", 0).to_i, dims.fetch("max", 0).to_i)
    else false
    end
  end

  def accepts_instruction?
    api_model_id == "qwen3-vl-embedding-8b"
  end

  private

  def preserve_api_identity_after_profile_creation
    return unless embedding_profiles.exists?
    if will_save_change_to_api_model_id? || will_save_change_to_inference_service_id?
      errors.add(:base, "Cannot change API model ID or inference service after profiles exist")
    end
  end

  def dimensions_are_valid
    valid = supported_dimensions.is_a?(Array) && supported_dimensions.any? && supported_dimensions.all? { |d| d.is_a?(Integer) && d.positive? } ||
            supported_dimensions.is_a?(Hash) && supported_dimensions["min"].is_a?(Integer) && supported_dimensions["max"].is_a?(Integer) && supported_dimensions["min"] > 0 && supported_dimensions["max"] >= supported_dimensions["min"]
    errors.add(:supported_dimensions, "must declare an allowed list or min/max") unless valid
  end
end
