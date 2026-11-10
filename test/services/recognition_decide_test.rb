require "test_helper"

class RecognitionDecideTest < ActiveSupport::TestCase
  def setup
    @admin = User.create!(email: "reviewer@example.com", role: "admin", password: "long-test-password-123", email_verified_at: Time.current)
    @service = InferenceService.create!(name: "mocked-service", base_url: "https://api.example.com",
      auth_secret_reference: "TEST_API_KEY", request_timeout_seconds: 300)
    @model = EmbeddingModel.create!(inference_service: @service, api_model_id: "qwen3-vl-embedding-8b",
      display_name: "Qwen", repository_name: "Qwen/test", supported_dimensions: [64, 128])
    @profile = EmbeddingProfiles::Create.call(model: @model, dimension: 64,
      model_revision: "a" * 40, preprocessing_version: "qwen3-vl-adapter-v1")
    @profile.update!(status: "preparing", config_sha256: "c" * 64)
    @policy = RecognitionPolicy.create!(embedding_profile: @profile, threshold: 0.5,
      evaluation_manifest_ref: "evaluation/manifest-1", evaluation_report_sha256: "e" * 64,
      approved_by: @admin, approved_at: Time.current, status: "approved")
  end

  def image_for(key:, collection:, role:, slot:, vector:, profile: @profile)
    identity = Identity.create!(external_identity_key: "CORE:#{key}", display_name: "Core #{key}") if collection == "core"
    image = FaceImage.create!(identity: identity, collection: collection, slot: slot, role: role,
      original_sha256: "1" * 64, inference_input_sha256: "2" * 64,
      storage_policy: "reference", dataset_identity_key: key)
    FaceEmbedding.create!(face_image: image, embedding_profile: profile, embedding: vector,
      input_sha256: "2" * 64, config_sha256: "c" * 64, normalized: true)
  end

  test "only Core SOURCE enrollment vectors take part in candidate search" do
    source = image_for(key: "001", collection: "core", role: "enrollment", slot: "SOURCE", vector: [1.0] + [0.0] * 63)
    query = image_for(key: "AD-1", collection: "additional", role: "sample_probe", slot: "P1", vector: [1.0] + [0.0] * 63)
    result = Recognition::Decide.call(embedding: query, profile: @profile, policy: @policy)
    assert_equal "matched", result.decision
    assert_equal source.face_image.identity, result.identity
  end

  test "below-threshold score is unknown and does not force a Core identity" do
    image_for(key: "001", collection: "core", role: "enrollment", slot: "SOURCE", vector: [1.0] + [0.0] * 63)
    query = image_for(key: "AD-1", collection: "additional", role: "sample_probe", slot: "P1", vector: [0.0, 1.0] + [0.0] * 62)
    result = Recognition::Decide.call(embedding: query, profile: @profile, policy: @policy)
    assert_equal "unknown", result.decision
    assert_nil result.identity
  end

  test "unapproved policy cannot yield a classification" do
    @policy.update!(status: "retired")
    query = image_for(key: "AD-1", collection: "additional", role: "sample_probe", slot: "P1", vector: [1.0] + [0.0] * 63)
    assert_raises(ArgumentError) { Recognition::Decide.call(embedding: query, profile: @profile, policy: @policy) }
  end
end
