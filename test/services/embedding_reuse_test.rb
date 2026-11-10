require "test_helper"

class EmbeddingReuseTest < ActiveSupport::TestCase
  test "1024 → 4096 → 1024 reuses the original image and makes zero client calls" do
    service = InferenceService.create!(name: "mocked-modal", base_url: "https://api.example.com",
      auth_secret_reference: "TEST_API_KEY", request_timeout_seconds: 300)
    model = EmbeddingModel.create!(inference_service: service, api_model_id: "qwen3-vl-embedding-8b",
      display_name: "Qwen", repository_name: "Qwen/test", supported_dimensions: { min: 64, max: 4096 })
    image = FaceImage.create!(identity: Identity.create!(external_identity_key: "CORE:001", display_name: "Core 001"),
      collection: "core", role: "enrollment", slot: "SOURCE", original_sha256: "a" * 64,
      inference_input_sha256: "b" * 64, storage_policy: "reference")
    low = EmbeddingProfiles::Create.call(model: model, dimension: 1024, model_revision: "c" * 40,
      preprocessing_version: "qwen3-vl-adapter-v1")
    high = EmbeddingProfiles::Create.call(model: model, dimension: 4096, model_revision: "c" * 40,
      preprocessing_version: "qwen3-vl-adapter-v1")
    [low, high].each do |profile|
      profile.update!(config_sha256: "e" * 64, status: "preparing")
      FaceEmbedding.create!(face_image: image, embedding_profile: profile,
        embedding: [1.0] + [0.0] * (profile.dimension - 1), input_sha256: "b" * 64,
        config_sha256: "e" * 64, normalized: true)
    end
    # Any outbound inference means the cache contract is broken.
    Embeddings::Client.stub(:new, ->(*) { flunk "The client must not be instantiated for cached embeddings" }) do
      assert_equal low.id, Embeddings::Ensure.call(image: image, profile: low).embedding_profile_id
      assert_equal high.id, Embeddings::Ensure.call(image: image, profile: high).embedding_profile_id
      assert_equal low.id, Embeddings::Ensure.call(image: image, profile: low).embedding_profile_id
    end
    assert_equal 2, FaceEmbedding.where(face_image: image).count
    assert_equal 0, EmbeddingRequest.count
  end
end
