require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  test "anonymous visits admin dashboard only via login redirect" do
    get admin_root_path
    assert_redirected_to sign_in_path
  end

  test "member cannot access admin dashboard" do
    user = User.create!(email: "member@example.com", role: "member", password: "test-password-long", email_verified_at: Time.current)
    post session_path, params: { email: user.email, password: "test-password-long" }
    get admin_root_path
    assert_response :forbidden
  end
end
