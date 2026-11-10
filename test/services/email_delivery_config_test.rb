require "test_helper"

class EmailDeliveryConfigTest < ActiveSupport::TestCase
  test "development/test provider configuration does not need live SMTP keys" do
    assert EmailDelivery.available? if Rails.env.test?
    assert_equal "smtp.resend.com", EmailDelivery::PROVIDERS.fetch("resend")
    assert_equal "smtp-relay.brevo.com", EmailDelivery::PROVIDERS.fetch("brevo")
    assert_equal "smtp.postmarkapp.com", EmailDelivery::PROVIDERS.fetch("postmark")
  end

  test "email-verification tokens change after verification" do
    user = User.create!(email: "verify-test@example.org", password: "excellent-long-password")
    token = user.generate_token_for(:email_verification)
    assert_equal user, User.find_by_token_for(:email_verification, token)
    user.update!(email_verified_at: Time.current)
    assert_nil User.find_by_token_for(:email_verification, token)
  end
end
