class PurgeOldAuthThrottlesJob < ApplicationJob
  queue_as :default
  def perform
    AuthThrottle.where("window_started_at < ?", 2.days.ago).where("blocked_until IS NULL OR blocked_until < ?", 2.days.ago).delete_all
  end
end
