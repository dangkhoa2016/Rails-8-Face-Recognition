require "test_helper"

class ActivationTest < ActiveSupport::TestCase
  test "cannot activate without full coverage and approved threshold" do
    admin = User.create!(email: "admin@example.com", role: "admin", password: "a-long-test-password", email_verified_at: Time.current)
    service = InferenceService.create!(name: "test-modal", base_url: "https://api.example.com",
      auth_secret_reference: "TEST_MODAL_TOKEN", request_timeout_seconds: 300)
    model = EmbeddingModel.create!(inference_service: service, api_model_id: "qwen3-vl-embedding-8b",
      display_name: "Qwen", repository_name: "Qwen/test", supported_dimensions: { min: 64, max: 4096 })
    profile = EmbeddingProfiles::Create.call(model: model, dimension: 1024, model_revision: "a" * 40,
      preprocessing_version: "source-bytes-v1")
    assert_raises(ArgumentError) { ApplicationSetting.current.activate!(profile: profile, policy: nil, actor: admin) }
    assert_nil ApplicationSetting.current.active_recognition_profile_id
  end
end
