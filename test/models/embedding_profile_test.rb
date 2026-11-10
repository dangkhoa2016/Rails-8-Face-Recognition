require "test_helper"

class EmbeddingProfileTest < ActiveSupport::TestCase
  def setup
    @service = InferenceService.create!(name: "test-modal", base_url: "https://api.example.com",
      auth_secret_reference: "TEST_MODAL_TOKEN", request_timeout_seconds: 300)
    @qwen = EmbeddingModel.create!(inference_service: @service, api_model_id: "qwen3-vl-embedding-8b",
      display_name: "Qwen", repository_name: "Qwen/test", supported_dimensions: { min: 64, max: 4096 })
    @wemm = EmbeddingModel.create!(inference_service: @service, api_model_id: "wemm-embedding-9b",
      display_name: "WeMM", repository_name: "Tencent/test", supported_dimensions: [1024, 2048, 4096])
    @revision = "a" * 40
  end

  test "same request config is reused after switching dimensions" do
    first = EmbeddingProfiles::Create.call(model: @qwen, dimension: 1024, model_revision: @revision,
      preprocessing_version: "source-bytes-v1")
    bigger = EmbeddingProfiles::Create.call(model: @qwen, dimension: 4096, model_revision: @revision,
      preprocessing_version: "source-bytes-v1")
    again = EmbeddingProfiles::Create.call(model: @qwen, dimension: 1024, model_revision: @revision,
      preprocessing_version: "source-bytes-v1")

    assert_equal first.id, again.id
    assert_not_equal first.id, bigger.id
    assert_equal 2, EmbeddingProfile.count
  end

  test "same dimension different model cannot reuse a profile" do
    qwen = EmbeddingProfiles::Create.call(model: @qwen, dimension: 1024, model_revision: @revision,
      preprocessing_version: "source-bytes-v1")
    wemm = EmbeddingProfiles::Create.call(model: @wemm, dimension: 1024, model_revision: @revision,
      preprocessing_version: "source-bytes-v1")
    assert_not_equal qwen.id, wemm.id
  end

  test "instruction is rejected by wemm" do
    assert_raises(ActiveRecord::RecordInvalid) do
      EmbeddingProfiles::Create.call(model: @wemm, dimension: 1024, model_revision: @revision,
        preprocessing_version: "source-bytes-v1", instruction: "Identify an individual")
    end
  end

  test "pinned config cannot be changed once preparing" do
    profile = EmbeddingProfiles::Create.call(model: @qwen, dimension: 1024, model_revision: @revision,
      preprocessing_version: "source-bytes-v1")
    profile.update!(status: "preparing")
    assert_not profile.update(dimension: 2048)
    assert profile.errors[:dimension].any?
  end
end
