# No fake faces, embeddings or thresholds are ever seeded.
# Create the first admin only when credentials are supplied securely at boot.
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  user = User.find_or_initialize_by(email: ENV.fetch("ADMIN_EMAIL").downcase.strip)
  if user.new_record?
    user.role = "admin"
    user.email_verified_at = Time.current
    user.password = ENV.fetch("ADMIN_PASSWORD")
    user.save!
    puts "Created initial administrator"
  else
    puts "Initial administrator already exists; credentials unchanged"
  end
end

if ENV["MODAL_EMBEDDINGS_API_URL"].present?
  service = InferenceService.find_or_initialize_by(name: "modal-embeddings")
  if service.new_record?
    service.base_url = ENV.fetch("MODAL_EMBEDDINGS_API_URL")
    service.auth_secret_reference = "EMBEDDINGS_API_BEARER_TOKEN"
    service.enabled = false # Explicit admin readiness check required before enabling real calls.
    service.request_timeout_seconds = 300
    service.save!
  end

  [
    { api_model_id: "qwen3-vl-embedding-8b", display_name: "Qwen3-VL Embedding 8B", repository_name: "Qwen/Qwen3-VL-Embedding-8B", supported_dimensions: { min: 64, max: 4096 } },
    { api_model_id: "wemm-embedding-9b", display_name: "WeMM Embedding 9B", repository_name: "tencent/WeMM-Embedding-9B", supported_dimensions: [64, 128, 256, 512, 1024, 2048, 4096] }
  ].each do |attributes|
    model = service.embedding_models.find_or_initialize_by(api_model_id: attributes.fetch(:api_model_id))
    if model.new_record?
      model.assign_attributes(attributes)
      model.enabled = false # Verify /v1/models capability and revision before allowing profiles.
      model.save!
    end
  end
end

ApplicationSetting.current
