require "test_helper"
require "tmpdir"

class NavigationUiTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "dashboard-admin@example.com", role: "admin", password: "strong-password-1234", email_verified_at: Time.current)
    @member = User.create!(email: "dashboard-member@example.com", role: "member", password: "strong-password-1234", email_verified_at: Time.current)
  end

  test "public explanatory pages render without authentication" do
    [root_path, about_path, privacy_path, terms_path, sign_in_path].each do |path|
      get path
      assert_response :success, "Expected #{path} to render"
    end
  end

  test "public pages keep the footer at the bottom of the flexible content column" do
    [root_path, about_path, privacy_path, terms_path, sign_in_path, new_verification_email_path].each do |path|
      get path
      assert_response :success, "Expected #{path} to render"
      assert_select "div[class~='min-h-screen'][class~='flex-col']", count: 1
      assert_select "main#main-content[class~='flex-1']", count: 1
      assert_select "main#main-content > div[class~='flex-1']", count: 1
      assert_select "main#main-content > footer", count: 1
    end
  end

  test "account recovery pages link back to sign in and registration" do
    [new_verification_email_path, new_password_reset_path].each do |path|
      get path
      assert_response :success
      assert_select "main#main-content a.text-link[href=?]", sign_in_path, count: 1
      assert_select "main#main-content a.text-link[href=?]", new_registration_path, count: 1
      assert_select "main#main-content a.btn-secondary[href=?]", sign_in_path, count: 0
      assert_select "main#main-content a.btn-secondary[href=?]", new_registration_path, count: 0
    end
  end

  test "member workspace routes render and admin pages are forbidden" do
    sign_in(@member)
    [samples_path, submissions_path, new_submission_path, recognition_attempts_path,
     new_recognition_attempt_path, data_resets_path, new_password_reset_path].each do |path|
      get path
      assert_response :success, "Expected #{path} to render"
    end
    get admin_root_path
    assert_response :forbidden
    get admin_embedding_profiles_path
    assert_response :forbidden
  end

  test "administrator dashboard and all management pages render with no imported data" do
    sign_in(@admin)
    [admin_root_path, admin_dataset_imports_path, new_admin_dataset_import_path,
     admin_identities_path, admin_face_images_path, admin_inference_services_path,
     new_admin_inference_service_path, admin_embedding_models_path,
     new_admin_embedding_model_path, admin_embedding_profiles_path,
     new_admin_embedding_profile_path, admin_recognition_policies_path,
     new_admin_recognition_policy_path, admin_unknown_tests_path,
     new_admin_unknown_test_path, admin_audit_events_path, admin_users_path, data_resets_path].each do |path|
      get path
      assert_response :success, "Expected #{path} to render"
    end
  end

  test "all nine administration indexes translate headings and browser titles" do
    sign_in(@admin)
    patch preferences_path, params: { locale: "vi" }
    assert_response :redirect

    {
      admin_embedding_profiles_path => "Hồ sơ embedding",
      admin_face_images_path => "Ảnh khuôn mặt",
      admin_identities_path => "Định danh Core",
      admin_dataset_imports_path => "Nhập bộ dữ liệu",
      admin_embedding_models_path => "Mô hình embedding",
      admin_inference_services_path => "Dịch vụ suy luận",
      admin_recognition_policies_path => "Chính sách nhận diện",
      admin_unknown_tests_path => "Thử nghiệm Unknown",
      admin_audit_events_path => "Nhật ký quản trị"
    }.each do |path, title|
      get path
      assert_response :success, "Expected #{path} to render"
      assert_select "html[lang='vi']", count: 1
      assert_select "h1", text: title
      assert_select "head title", text: /#{Regexp.escape(title)} · Rails 8 Face Recognition/
    end

    get admin_face_images_path
    assert_select "label[for='collection']", text: "Bộ sưu tập"
    assert_select "label[for='role']", text: "Vai trò"
    assert_select "select[name='collection'] option", text: "Bộ Core"
    assert_select "select[name='role'] option", text: "Ảnh thăm dò"

    event = AdminAuditEvent.create!(
      actor: @admin, action: "dataset_import.created", subject_type: "DatasetImport", subject_id: 123
    )
    get admin_audit_events_path
    assert_response :success
    assert_select "td", text: /Đăng ký snapshot bộ dữ liệu/
    assert_select "td", text: /Lần nhập bộ dữ liệu #123/
    assert_select "td", text: /dataset_import.created/

    patch preferences_path, params: { locale: "en" }
    assert_response :redirect
    get admin_embedding_profiles_path
    assert_select "h1", text: "Embedding profiles"
    assert_select "head title", text: /Embedding profiles · Rails 8 Face Recognition/
  end

  test "ui catalog uses symbol keys and retains English fallback" do
    I18n.with_locale(:vi) do
      assert_equal "Hồ sơ embedding", ApplicationController.helpers.ui("Embedding profiles")
      assert_equal "Ảnh khuôn mặt", ApplicationController.helpers.ui("Face images")
      assert_equal "+ Thêm mô hình", ApplicationController.helpers.ui("+ Add model")
      assert_equal "Untranslated sample", ApplicationController.helpers.ui("Untranslated sample")
      assert_equal "Trang 2/4 · 100 bản ghi",
        I18n.t("admin_indexes.pagination.summary", page: 2, pages: 4, total: 100)
      assert_equal "Ảnh enrollment", I18n.t("status.enrollment")
    end
    I18n.with_locale(:en) do
      assert_equal "Embedding profiles", ApplicationController.helpers.ui("Embedding profiles")
      assert_equal "Page 2 of 4 · 100 records",
        I18n.t("admin_indexes.pagination.summary", page: 2, pages: 4, total: 100)
    end
  end

  test "embedding profile form explains workflow in English and Vietnamese" do
    sign_in(@admin)

    get new_admin_embedding_profile_path
    assert_response :success
    assert_select "section[data-testid='embedding-profile-guide'] ol > li", count: 4
    assert_select "h1", text: "Create or reuse an embedding profile"
    assert_select "form[action=?] input[type='submit'][disabled]", admin_embedding_profiles_path, count: 1
    assert_select "a[href=?]", new_admin_embedding_model_path, count: 1
    assert_select "input[name='preprocessing_version'][value='qwen3-vl-adapter-v1']", count: 0
    assert_select "input[name='dimension'][value='1024']", count: 0

    patch preferences_path, params: { locale: "vi" }
    assert_response :redirect
    get new_admin_embedding_profile_path
    assert_response :success
    assert_select "html[lang='vi']", count: 1
    assert_select "h1", text: "Tạo hoặc tái sử dụng hồ sơ embedding"
    assert_select "#embedding-profile-guide-title", text: "Hướng dẫn cấu hình hồ sơ embedding"
    assert_select "label[for='dimension']", text: "Số chiều embedding"
    assert_select "label[for='preprocessing_version']", text: "Phiên bản tiền xử lý"
    assert_select "input[type='submit'][value='Lưu hoặc tái sử dụng hồ sơ']", count: 1
    assert_no_match(/New Embedding Profile|Create or reuse a profile|Pinned checkpoint SHA/, response.body)
  end

  test "embedding profile form is submittable when an enabled model exists" do
    service = InferenceService.create!(
      name: "profile-ui-test", base_url: "https://example.com",
      auth_secret_reference: "PROFILE_UI_TEST_TOKEN", request_timeout_seconds: 300
    )
    EmbeddingModel.create!(
      inference_service: service, api_model_id: "qwen3-vl-embedding-8b",
      display_name: "Qwen UI test", repository_name: "Qwen/test",
      supported_dimensions: [1024, 4096], enabled: true
    )
    sign_in(@admin)

    get new_admin_embedding_profile_path
    assert_response :success
    assert_select "select[name='embedding_model_id'] option", text: /Qwen UI test/
    assert_select "form[action=?] input[type='submit']:not([disabled])", admin_embedding_profiles_path, count: 1
    assert_select "div[data-testid='embedding-profile-no-models']", count: 0
    assert_select "input[name='model_revision'][pattern='[0-9a-f]{40,64}']", count: 1
  end

  test "recognition policy form explains calibration and is translated into Vietnamese" do
    sign_in(@admin)

    get new_admin_recognition_policy_path
    assert_response :success
    assert_select "section[data-testid='recognition-policy-guide'] ol > li", count: 4
    assert_select "h1", text: "Register a recognition policy"
    assert_select "form input[type='submit'][disabled]", count: 1
    assert_select "a[href=?]", new_admin_embedding_profile_path, count: 1

    patch preferences_path, params: { locale: "vi" }
    assert_response :redirect
    get new_admin_recognition_policy_path
    assert_response :success
    assert_select "html[lang='vi']", count: 1
    assert_select "h1", text: "Đăng ký chính sách nhận diện"
    assert_select "#recognition-policy-guide-title", text: "Hướng dẫn thiết lập chính sách nhận diện"
    assert_select "label[for='recognition_policy_threshold']", text: "Ngưỡng tương đồng cosine"
    assert_select "label[for='recognition_policy_evaluation_manifest_ref']", text: "Tham chiếu manifest đánh giá"
    assert_select "input[type='submit'][value='Lưu bản nháp chính sách']", count: 1
    assert_no_match(/Register a recognition policy|Calibrated cosine threshold|Evaluation report SHA-256/, response.body)
  end

  test "recognition policy draft allows blank report SHA but rejects malformed evidence" do
    draft = RecognitionPolicy.new(status: "not_calibrated", evaluation_report_sha256: "")
    draft.valid?
    assert_empty draft.errors[:evaluation_report_sha256]

    draft.evaluation_report_sha256 = "incorrect-hash"
    draft.valid?
    assert_not_empty draft.errors[:evaluation_report_sha256]
  end

  test "admin sidebar has exactly one active item for nested routes" do
    sign_in(@admin)
    [admin_root_path, admin_dataset_imports_path, new_admin_dataset_import_path,
     admin_embedding_profiles_path, new_admin_embedding_profile_path].each do |path|
      get path
      assert_response :success
      assert_select "aside nav a[aria-current='page']", count: 1, message: "Expected one active sidebar item for #{path}"
    end

    get admin_dataset_imports_path
    assert_select "aside nav a[href=?][aria-current='page']", admin_root_path, count: 0
    assert_select "aside nav a[href=?][aria-current='page']", admin_dataset_imports_path, count: 1
  end

  test "recognition navigation highlights only the relevant sidebar item" do
    sign_in(@member)

    get new_recognition_attempt_path
    assert_response :success
    assert_select "aside nav a[aria-current='page']", count: 1
    assert_select "aside nav a[href=?][aria-current='page']", new_recognition_attempt_path, count: 1
    assert_select "aside nav a[href=?][aria-current='page']", recognition_attempts_path, count: 0

    get recognition_attempts_path
    assert_response :success
    assert_select "aside nav a[aria-current='page']", count: 1
    assert_select "aside nav a[href=?][aria-current='page']", new_recognition_attempt_path, count: 0
    assert_select "aside nav a[href=?][aria-current='page']", recognition_attempts_path, count: 1
  end

  test "dataset import explains missing server configuration and verifies staged metadata" do
    sign_in(@admin)
    record = DatasetImport.create!(source_name: "CompactFaces", source_url: "https://example.org/compactfaces",
      dataset_version: "1.0.0", import_status: "pending")
    original_root = ENV["DATASET_IMPORT_ROOT"]

    begin
      ENV.delete("DATASET_IMPORT_ROOT")
      get admin_dataset_import_path(record)
      assert_response :success
      assert_select "details[data-testid='dataset-setup-guide'][open]", count: 1
      assert_select "main pre code", text: /hf download dangkhoa2016\/compactfaces-synthetic-face-dataset/
      assert_select "button[disabled]", text: "Verify and import", count: 1

      Dir.mktmpdir("compactfaces-path-check") do |root|
        ENV["DATASET_IMPORT_ROOT"] = root
        get admin_dataset_import_path(record)
        assert_response :success
        assert_select "button[disabled]", text: "Verify and import", count: 1

        metadata_dir = File.join(root, "data", "train")
        FileUtils.mkdir_p(metadata_dir)
        File.write(File.join(metadata_dir, "metadata.csv"), "file_name,identity_key,collection,slot,sha256\n")
        get admin_dataset_import_path(record)
        assert_response :success
        assert_select "details[data-testid='dataset-setup-guide'][open]", count: 0
        assert_select "button:not([disabled])", text: "Verify and import", count: 1
      end
    ensure
      original_root.nil? ? ENV.delete("DATASET_IMPORT_ROOT") : ENV["DATASET_IMPORT_ROOT"] = original_root
    end
  end

  private

  def sign_in(user)
    post session_path, params: { email: user.email, password: "strong-password-1234" }
    assert_response :redirect
  end
end
