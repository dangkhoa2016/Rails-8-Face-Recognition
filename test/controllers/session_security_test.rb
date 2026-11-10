require "test_helper"

class SessionSecurityTest < ActionDispatch::IntegrationTest
  setup do
    AuthThrottle.delete_all
    @password = "secure-session-rotation-12345"
    @admin = User.create!(email: "cross-browser-admin@example.org", role: "admin",
      email_verified_at: Time.current, password: @password)
    @member = User.create!(email: "cross-browser-member@example.org", role: "member",
      email_verified_at: Time.current, password: @password)
  end

  test "admin revocation terminates an existing session on another browser" do
    member_browser = signed_in_browser(@member)
    admin_browser = signed_in_browser(@admin)
    member_browser.get samples_path
    assert_equal 200, member_browser.response.status

    old_nonce = @member.session_nonce
    admin_browser.patch admin_user_path(@member), params: { operation: "revoke_sessions" }
    assert_equal 302, admin_browser.response.status
    assert_not_equal old_nonce, @member.reload.session_nonce

    member_browser.get samples_path
    assert_login_required(member_browser)
  end

  test "suspension blocks an active session and future password logins" do
    member_browser = signed_in_browser(@member)
    admin_browser = signed_in_browser(@admin)
    admin_browser.patch admin_user_path(@member), params: { operation: "suspend" }
    assert_equal 302, admin_browser.response.status

    member_browser.get samples_path
    assert_login_required(member_browser)
    member_browser.post session_path, params: { email: @member.email, password: @password }
    assert_equal 422, member_browser.response.status
  end

  test "promotion does not silently grant administrator access to an old session" do
    member_browser = signed_in_browser(@member)
    admin_browser = signed_in_browser(@admin)
    admin_browser.patch admin_user_path(@member), params: { operation: "promote" }
    assert_equal 302, admin_browser.response.status
    assert @member.reload.admin?

    member_browser.get admin_root_path
    assert_login_required(member_browser)
    member_browser.post session_path, params: { email: @member.email, password: @password }
    assert_equal 302, member_browser.response.status
    member_browser.get admin_root_path
    assert_equal 200, member_browser.response.status
  end

  private

  def signed_in_browser(user)
    browser = open_session
    browser.post session_path, params: { email: user.email, password: @password }
    assert_equal 302, browser.response.status
    browser
  end

  def assert_login_required(browser)
    assert_equal 302, browser.response.status
    assert_includes [sign_in_path, root_path], URI.parse(browser.response.location).path
  end
end
