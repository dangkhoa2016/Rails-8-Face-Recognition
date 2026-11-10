require "test_helper"

class DataResetAndRolesTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @pw = "safe-long-password-789"
    @admin = User.create!(email: "reset-admin@example.com", role: "admin", password: @pw, email_verified_at: Time.current)
    @alice = User.create!(email: "reset-alice@example.com", role: "member", password: @pw, email_verified_at: Time.current)
    @bob = User.create!(email: "reset-bob@example.com", role: "member", password: @pw, email_verified_at: Time.current)
    @a = create_temporary(@alice)
    @b = create_temporary(@bob)
  end

  test "member reset deletes only own submissions, preserves other member and reference image" do
    reference = FaceImage.create!(collection: "core", role: "sample_probe", slot: "P1", original_sha256: "a" * 64, storage_policy: "reference")
    login(@alice)
    perform_enqueued_jobs do
      post data_resets_path, params: { scope: "mine", confirmation: "RESET MY DATA" }
    end
    assert_response :redirect
    assert_not FaceImage.exists?(@a.id)
    assert FaceImage.exists?(@b.id)
    assert FaceImage.exists?(reference.id)
    assert_equal "completed", DataReset.last.status
  end

  test "member cannot trigger global reset" do
    login(@alice)
    post data_resets_path, params: { scope: "all_test_activity", confirmation: "RESET ALL TEST DATA" }
    assert_response :forbidden
    assert FaceImage.exists?(@a.id)
    assert FaceImage.exists?(@b.id)
  end

  test "global test reset does not delete identity and reference" do
    reference = FaceImage.create!(collection: "core", role: "sample_probe", slot: "P1", original_sha256: "a" * 64, storage_policy: "reference")
    login(@admin)
    perform_enqueued_jobs do
      post data_resets_path, params: { scope: "all_test_activity", confirmation: "RESET ALL TEST DATA" }
    end
    assert_not FaceImage.exists?(@a.id)
    assert_not FaceImage.exists?(@b.id)
    assert FaceImage.exists?(reference.id)
    assert AdminAuditEvent.exists?(action: "test_data.reset_completed")
  end

  test "member cannot clear sample probe cache" do
    login(@alice)
    post data_resets_path, params: { scope: "probe_cache", confirmation: "RESET PROBE CACHE" }
    assert_response :forbidden
  end

  test "admin-only user controls guard member access and protect last admin" do
    login(@alice)
    patch admin_user_path(@bob), params: { operation: "promote" }
    assert_response :forbidden
    delete session_path
    login(@admin)
    patch admin_user_path(@admin), params: { operation: "demote" }
    assert_redirected_to admin_users_path
    assert @admin.reload.admin?
    patch admin_user_path(@bob), params: { operation: "promote" }
    assert_redirected_to admin_users_path
    assert @bob.reload.admin?
    patch admin_user_path(@alice), params: { operation: "suspend" }
    assert_not @alice.reload.enabled?
    assert AdminAuditEvent.exists?(action: "user.promote")
  end

  test "suspending a member revokes their session and prevents subsequent login" do
    login(@alice)
    get samples_path
    assert_response :success
    delete session_path
    login(@admin)
    patch admin_user_path(@alice), params: { operation: "suspend" }
    assert_redirected_to admin_users_path
    delete session_path
    post session_path, params: { email: @alice.email, password: @pw }
    assert_response :unprocessable_entity
    login(@admin)
    patch admin_user_path(@alice), params: { operation: "activate" }
    assert_redirected_to admin_users_path
    delete session_path
    login(@alice)
    get samples_path
    assert_response :success
  end

  private

  def login(user)
    post session_path, params: { email: user.email, password: @pw }
    assert_response :redirect
  end

  def create_temporary(user)
    FaceImage.create!(owner_user: user, collection: "user", role: "submission", original_sha256: "f" * 64,
      inference_input_sha256: "f" * 64, expires_at: 1.day.from_now, storage_policy: "transient")
  end
end
