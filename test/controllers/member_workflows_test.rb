require "test_helper"
require "base64"
require "digest"
require "stringio"

class MemberWorkflowsTest < ActionDispatch::IntegrationTest
  PNG_BYTES = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==")

  def setup
    @alice = User.create!(email: "alice@example.com", role: "member", password: "a-long-password-123", email_verified_at: Time.current)
    @bob = User.create!(email: "bob@example.com", role: "member", password: "a-long-password-123", email_verified_at: Time.current)
    @photo = FaceImage.new(owner_user: @alice, collection: "user", role: "submission",
      storage_policy: "transient", original_sha256: Digest::SHA256.hexdigest(PNG_BYTES),
      inference_input_sha256: Digest::SHA256.hexdigest(PNG_BYTES), expires_at: 1.day.from_now)
    @photo.image.attach(io: StringIO.new(PNG_BYTES), filename: "authorized.png", content_type: "image/png", identify: false)
    @photo.save!
  end

  test "another member cannot see or delete private submissions or previews" do
    post session_path, params: { email: @bob.email, password: "a-long-password-123" }
    get submission_path(@photo)
    assert_response :not_found
    get face_image_path(@photo)
    assert_response :not_found
    delete submission_path(@photo)
    assert_response :not_found
    assert FaceImage.exists?(@photo.id)
  end

  test "owner can view private preview and delete all submission records" do
    post session_path, params: { email: @alice.email, password: "a-long-password-123" }
    get face_image_path(@photo)
    assert_response :success
    assert_includes response.headers["Cache-Control"], "private"
    assert_includes response.headers["Cache-Control"], "no-store"
    delete submission_path(@photo)
    assert_redirected_to submissions_path
    assert_not FaceImage.exists?(@photo.id)
  end

  test "member cannot manage enrollment or create an inference model" do
    post session_path, params: { email: @alice.email, password: "a-long-password-123" }
    post admin_embedding_models_path, params: { embedding_model: { api_model_id: "evil-model" }, supported_dimensions_json: "[1024]" }
    assert_response :forbidden
    patch admin_identity_path(1), params: { active: "false" }
    assert_response :forbidden
  end

  test "recognition is gated until a profile and approved policy are active" do
    post session_path, params: { email: @alice.email, password: "a-long-password-123" }
    post recognition_attempts_path, params: { face_image_id: @photo.id }
    assert_redirected_to new_recognition_attempt_path
    assert_equal 0, RecognitionAttempt.count
  end
end
