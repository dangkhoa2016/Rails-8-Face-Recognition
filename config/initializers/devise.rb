require "devise/orm/active_record"

# Devise 5.0.4 authenticates via Warden while application-specific
# email verification, signed password recovery and PostgreSQL throttling
# remain explicit and independently testable.
Devise.setup do |config|
  config.mailer_sender = ENV.fetch("EMAIL_FROM", "no-reply@example.com")
  config.parent_controller = "ApplicationController"
  config.authentication_keys = [:email]
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.password_length = 12..128
  config.timeout_in = 30.minutes
  config.sign_out_via = :delete
  config.skip_session_storage = [:http_auth]
end
