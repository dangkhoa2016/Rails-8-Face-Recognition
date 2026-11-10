require "test_helper"

class SelfServiceAuthTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    AuthThrottle.delete_all
    clear_enqueued_jobs
    @password = "some-excellent-password-456"
  end

  test "registration ignores hostile role and requires email verification before login" do
    assert_difference "User.count", 1 do
      assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
        post registration_path, params: { user: { email: "Signup@Example.COM", password: @password,
          password_confirmation: @password, role: "admin", email_verified_at: Time.current }, accept_terms: "1" }
      end
    end
    assert_redirected_to sign_in_path
    user = User.find_by!(email: "signup@example.com")
    assert_equal "member", user.role
    assert_nil user.email_verified_at
    post session_path, params: { email: user.email, password: @password }
    assert_response :unprocessable_entity

    token = user.generate_token_for(:email_verification)
    get email_verification_path(token: token)
    assert_response :success
    post email_verification_path, params: { token: token }
    assert_redirected_to sign_in_path
    assert user.reload.verified?
    assert_nil User.find_by_token_for(:email_verification, token)
    post session_path, params: { email: user.email, password: @password }
    assert_redirected_to samples_path
  end

  test "registration requires terms and does not create an admin from submitted attributes" do
    assert_no_difference "User.count" do
      post registration_path, params: { user: { email: "no-consent@example.com", password: @password,
        password_confirmation: @password, role: "admin" } }
    end
    assert_response :unprocessable_entity
  end

  test "login throttling is stored in database and returns 429 after repeated attempts" do
    user = User.create!(email: "protected@example.com", role: "member", password: @password, email_verified_at: Time.current)
    5.times do
      post session_path, params: { email: user.email, password: "wrong-password-123456" }
      assert_response :unprocessable_entity
    end
    post session_path, params: { email: user.email, password: @password }
    assert_response :too_many_requests
    assert AuthThrottle.count >= 3
    assert AuthThrottle.all.none? { |item| item.key_hash.include?(user.email) }
  end

  test "password reset invalidates earlier token and sessions" do
    user = User.create!(email: "reset@example.com", role: "member", password: @password, email_verified_at: Time.current)
    post session_path, params: { email: user.email, password: @password }
    assert_redirected_to samples_path
    original_nonce = user.session_nonce
    token = user.generate_token_for(:password_reset)
    get edit_password_reset_path(token: token)
    assert_response :success
    patch update_password_reset_path, params: { token: token, password: "different-password-789", password_confirmation: "different-password-789" }
    assert_redirected_to sign_in_path
    assert_nil User.find_by_token_for(:password_reset, token)
    assert_not_equal original_nonce, user.reload.session_nonce
    get samples_path
    assert_redirected_to sign_in_path
    post session_path, params: { email: user.email, password: "different-password-789" }
    assert_redirected_to samples_path
  end

  test "forgot-password and verification resend do not disclose unknown accounts" do
    post password_reset_path, params: { email: "not-listed@example.com" }
    assert_redirected_to sign_in_path
    post verification_email_path, params: { email: "not-listed@example.com" }
    assert_redirected_to sign_in_path
  end

  test "system appearance preference can be selected independently from language" do
    patch preferences_path, params: { locale: "en", theme: "auto" }
    get root_path
    assert_select "html[lang='en'][data-theme='auto']"
  end

  test "AJAX preferences return 204 without redirect and persist the signed choices" do
    patch preferences_path, params: { theme: "dark" }, as: :json
    assert_response :no_content
    assert_nil response.location

    patch preferences_path, params: { locale: "vi" }, as: :json
    assert_response :no_content
    assert_nil response.location

    get root_path
    assert_select "html[lang='vi'][data-theme='dark']"
  end

  test "invalid email verification link is not treated as valid" do
    get email_verification_path(token: "invalid")
    assert_response :success
    assert_select "form[action=?]", email_verification_path, count: 0
  end

  test "preferences persist in signed cookies, with invalid values ignored" do
    patch preferences_path, params: { locale: "vi", theme: "light" }
    assert_redirected_to root_path
    get root_path
    assert_response :success
    assert_select "html[lang='vi'][data-theme='light']"
    assert_match /Tổng quan/, response.body
    patch preferences_path, params: { locale: "xx", theme: "invalid" }
    get root_path
    assert_select "html[lang='vi'][data-theme='light']"
  end
end
