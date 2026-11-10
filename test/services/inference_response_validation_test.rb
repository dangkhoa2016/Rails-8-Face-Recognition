require "test_helper"

class InferenceResponseValidationTest < ActiveSupport::TestCase
  def setup
    service = InferenceService.create!(name: "example-api", base_url: "https://api.example.com",
      auth_secret_reference: "TEST_API_KEY", request_timeout_seconds: 300)
    model = EmbeddingModel.create!(inference_service: service, api_model_id: "wemm-embedding-9b",
      display_name: "WeMM", repository_name: "Tencent/WeMM", supported_dimensions: [64])
    @profile = EmbeddingProfiles::Create.call(model: model, dimension: 64,
      model_revision: "a" * 40, preprocessing_version: "wemm-adapter-v1")
    @profile.update!(config_sha256: "c" * 64)
    @client = Embeddings::Client.new(service)
    @response = {
      "model" => "wemm-embedding-9b", "dimension" => 64, "revision" => "a" * 40,
      "input_sha256" => "b" * 64, "normalized" => true,
      "vector" => [1.0] + [0.0] * 63,
      "embedding_metadata" => { "preprocessing_version" => "wemm-adapter-v1",
        "config_sha256" => "c" * 64, "instruction_sha256" => nil }
    }
  end

  test "accepts a valid pinned, normalized response without network" do
    assert_nil @client.send(:validate_response!, @response, @profile, "b" * 64)
  end

  test "rejects checkpoint drift" do
    @response["revision"] = "d" * 40
    error = assert_raises(Embeddings::Client::Error) { @client.send(:validate_response!, @response, @profile, "b" * 64) }
    assert_equal "configuration_drift", error.code
  end

  test "rejects vector dimension drift" do
    @response["vector"] = [1.0, 0.0]
    error = assert_raises(Embeddings::Client::Error) { @client.send(:validate_response!, @response, @profile, "b" * 64) }
    assert_equal "invalid_vector", error.code
  end
end
