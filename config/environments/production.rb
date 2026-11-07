Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false
  config.force_ssl = true
  config.assume_ssl = true
  config.log_level = :info
  config.log_tags = [:request_id]
  config.active_storage.service = :r2_submissions
  config.active_job.queue_adapter = :solid_queue
  config.action_mailer.perform_caching = false
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
end
