require "test_helper"

class AuthRateLimiterTest < ActiveSupport::TestCase
  setup { AuthThrottle.delete_all }

  test "rate limiter blocks after five same-IP same-account login attempts without storing emails" do
    5.times { Auth::RateLimiter.consume!(action: :login, email: "person@example.org", ip: "192.0.2.10") }
    assert_raises(Auth::RateLimiter::Limited) { Auth::RateLimiter.consume!(action: :login, email: "person@example.org", ip: "192.0.2.10") }
    assert AuthThrottle.where.not(blocked_until: nil).exists?
    assert AuthThrottle.pluck(:key_hash).all? { |digest| digest.match?(/\A[0-9a-f]{64}\z/) }
  end

  test "blocked login bucket resets after its fifteen-minute window" do
    5.times { Auth::RateLimiter.consume!(action: :login, email: "expiry@example.org", ip: "192.0.2.80") }
    assert_raises(Auth::RateLimiter::Limited) do
      Auth::RateLimiter.consume!(action: :login, email: "expiry@example.org", ip: "192.0.2.80")
    end

    travel 16.minutes do
      assert_nothing_raised do
        Auth::RateLimiter.consume!(action: :login, email: "expiry@example.org", ip: "192.0.2.80")
      end
    end
    assert AuthThrottle.where(blocked_until: nil).exists?
  end

  test "account limit applies across distinct addresses" do
    8.times { |i| Auth::RateLimiter.consume!(action: :login, email: "person@example.org", ip: "192.0.2.#{i}") }
    assert_raises(Auth::RateLimiter::Limited) { Auth::RateLimiter.consume!(action: :login, email: "person@example.org", ip: "192.0.2.99") }
  end
end
