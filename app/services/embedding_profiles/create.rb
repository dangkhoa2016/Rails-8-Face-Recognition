require "digest"
require "json"

module EmbeddingProfiles
  class Create
    def self.call(model:, dimension:, model_revision:, preprocessing_version:, instruction: nil)
      dimension = Integer(dimension)
      instruction = instruction.presence
      # Deterministic; do not encode service token or mutable server response in this digest.
      canonical = {
        "model" => model.api_model_id,
        "service_id" => model.inference_service_id,
        "dimension" => dimension,
        "model_revision" => model_revision,
        "preprocessing_version" => preprocessing_version,
        "instruction" => instruction
      }
      digest = Digest::SHA256.hexdigest(JSON.generate(canonical))
      EmbeddingProfile.create_or_find_by!(
        embedding_model: model,
        dimension: dimension,
        model_revision: model_revision,
        request_config_digest: digest
      ) do |profile|
        profile.instruction = instruction
        profile.preprocessing_version = preprocessing_version
        profile.status = "draft"
      end
    end
  end
end
