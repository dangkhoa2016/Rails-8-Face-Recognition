require "test_helper"

class EmbeddingPersistenceTest < ActiveSupport::TestCase
  def setup
    @identity = Identity.create!(external_identity_key: "CORE:test", display_name: "Core test")
    @image = FaceImage.create!(identity: @identity, collection: "core", slot: "SOURCE", role: "enrollment",
      original_sha256: "a" * 64, inference_input_sha256: "b" * 64, storage_policy: "reference")
    service = InferenceService.create!(name: "test-modal", base_url: "https://api.example.com",
      auth_secret_reference: "TEST_MODAL_TOKEN", request_timeout_seconds: 300)
    @model = EmbeddingModel.create!(inference_service: service, api_model_id: "qwen3-vl-embedding-8b",
      display_name: "Qwen", repository_name: "Qwen/test", supported_dimensions: { min: 64, max: 4096 })
  end

  test "two dimensions coexist for the same face image without overwriting" do
    profiles = [64, 128].map do |dimension|
      profile = EmbeddingProfiles::Create.call(model: @model, dimension: dimension,
        model_revision: "c" * 40, preprocessing_version: "source-bytes-v1")
      profile.update!(config_sha256: "d" * 64, status: "preparing")
      FaceEmbedding.create!(face_image: @image, embedding_profile: profile,
        embedding: [1.0] + [0.0] * (dimension - 1),
        input_sha256: "b" * 64, config_sha256: "d" * 64, normalized: true)
      profile
    end
    assert_equal 2, FaceEmbedding.where(face_image: @image).count
    assert_equal [64, 128], profiles.map(&:dimension)
    assert_equal profiles.first.id, EmbeddingProfiles::Create.call(model: @model, dimension: 64,
      model_revision: "c" * 40, preprocessing_version: "source-bytes-v1").id
    assert_equal 1, FaceEmbedding.where(face_image: @image, embedding_profile: profiles.first).count
  end

  test "vector with wrong dimension is rejected" do
    profile = EmbeddingProfiles::Create.call(model: @model, dimension: 64,
      model_revision: "c" * 40, preprocessing_version: "source-bytes-v1")
    profile.update!(config_sha256: "d" * 64)
    embedding = FaceEmbedding.new(face_image: @image, embedding_profile: profile,
      embedding: [1.0, 0.0], input_sha256: "b" * 64, config_sha256: "d" * 64, normalized: true)
    assert_not embedding.valid?
  end

  test "confirmed configuration digest must match" do
    profile = EmbeddingProfiles::Create.call(model: @model, dimension: 64,
      model_revision: "c" * 40, preprocessing_version: "source-bytes-v1")
    profile.update!(config_sha256: "d" * 64)
    embedding = FaceEmbedding.new(face_image: @image, embedding_profile: profile,
      embedding: [1.0] + [0.0] * 63, input_sha256: "b" * 64, config_sha256: "e" * 64, normalized: true)
    assert_not embedding.valid?
    assert embedding.errors[:config_sha256].any?
  end
end
