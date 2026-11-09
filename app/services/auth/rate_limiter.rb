require "openssl"

module Auth
  # Shared PostgreSQL-backed throttles; neither raw addresses nor emails are stored.
  # Unique index and row locks keep limits effective across Puma/worker processes.
  class RateLimiter
    class Limited < StandardError; end

    LIMITS = {
      "login" => [["ip", 30, 15.minutes], ["email", 8, 15.minutes], ["pair", 5, 15.minutes]],
      "register" => [["ip", 6, 1.hour], ["email", 3, 1.hour]],
      "verify_resend" => [["ip", 10, 1.hour], ["email", 3, 1.hour]],
      "password_reset" => [["ip", 10, 1.hour], ["email", 3, 1.hour]],
      "data_reset" => [["ip", 8, 1.hour], ["email", 4, 1.hour]],
      "upload" => [["ip", 30, 1.hour], ["email", 10, 1.hour]],
      "recognition" => [["ip", 90, 1.hour], ["email", 30, 1.hour]],
      "unknown_test" => [["ip", 20, 1.hour], ["email", 10, 1.hour]]
    }.freeze

    def self.consume!(action:, email:, ip:)
      action = action.to_s
      raise ArgumentError, "unknown throttle action" unless LIMITS.key?(action)
      normalized_email = email.to_s.strip.downcase.first(254)
      normalized_ip = ip.to_s.first(64)
      fingerprints = { "ip" => normalized_ip, "email" => normalized_email, "pair" => "#{normalized_ip}|#{normalized_email}" }

      LIMITS.fetch(action).each do |dimension, limit, window|
        digest = OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base,
          "#{action}:#{dimension}:#{fingerprints.fetch(dimension)}")
        record = AuthThrottle.create_or_find_by!(key_hash: digest)
        limited = false
        record.with_lock do
          now = Time.current
          if record.window_started_at <= now - window
            record.attempts = 0
            record.window_started_at = now
            record.blocked_until = nil
          end
          if record.blocked_until && record.blocked_until > now
            limited = true
          else
            record.attempts += 1
            if record.attempts > limit
              record.blocked_until = record.window_started_at + window
              limited = true
            end
            record.save!
          end
        end
        raise Limited if limited
      end
    end
  end
end
