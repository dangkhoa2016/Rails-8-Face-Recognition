# All providers use authenticated TLS SMTP through Action Mailer. No provider
# credentials or URLs are stored in the application database or sent to browsers.
class EmailDelivery
  PROVIDERS = {
    "resend" => "smtp.resend.com",
    "brevo" => "smtp-relay.brevo.com",
    "postmark" => "smtp.postmarkapp.com",
    "sendpulse" => nil,
    "smtp" => nil
  }.freeze

  def self.provider
    return "test" if Rails.env.test?
    ENV.fetch("EMAIL_PROVIDER", Rails.env.production? ? "disabled" : "file").downcase
  end

  def self.available?
    return true if provider == "test"
    return !Rails.env.production? if provider == "file"
    return false unless PROVIDERS.key?(provider)
    smtp_host.present? && smtp_username.present? && ENV["EMAIL_SMTP_PASSWORD"].present? &&
      ENV["EMAIL_FROM"].present? && ENV["APP_HOST"].present?
  end

  def self.smtp_host
    PROVIDERS.fetch(provider, nil) || ENV["EMAIL_SMTP_HOST"].to_s
  end

  def self.smtp_username
    ENV["EMAIL_SMTP_USERNAME"].presence || ("resend" if provider == "resend")
  end

  def self.configure!(config)
    config.action_mailer.default_url_options = {
      host: ENV.fetch("APP_HOST", "localhost"),
      protocol: Rails.env.production? ? "https" : ENV.fetch("APP_PROTOCOL", "http")
    }
    config.action_mailer.perform_caching = false
    return unless available?

    settings = nil
    method = nil
    if provider == "test"
      method = :test
    elsif provider == "file"
      method = :file
      settings = { location: Rails.root.join("tmp", "mails").to_s }
      config.action_mailer.file_settings = settings
    else
      method = :smtp
      port = Integer(ENV.fetch("EMAIL_SMTP_PORT", "587"))
      settings = {
        address: smtp_host, port: port, domain: ENV.fetch("EMAIL_HELO_DOMAIN", ENV.fetch("APP_HOST")),
        user_name: smtp_username, password: ENV.fetch("EMAIL_SMTP_PASSWORD"),
        authentication: :plain, enable_starttls: (port != 465),
        ssl: (port == 465), openssl_verify_mode: "peer", open_timeout: 10, read_timeout: 20
      }
      config.action_mailer.smtp_settings = settings
    end
    config.action_mailer.delivery_method = method
    # after_initialize runs after the ActionMailer railtie reads app config.
    # Apply runtime class settings too, so messages use the selected provider.
    ActionMailer::Base.default_url_options = config.action_mailer.default_url_options
    ActionMailer::Base.delivery_method = method
    ActionMailer::Base.smtp_settings = settings if method == :smtp
    ActionMailer::Base.file_settings = settings if method == :file
  end
end
