require "active_support/core_ext/integer/time"
Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.active_storage.service = :local
  config.active_job.queue_adapter = :solid_queue # Run bin/jobs alongside bin/dev for background work and retention.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.assets.quiet = true
end
