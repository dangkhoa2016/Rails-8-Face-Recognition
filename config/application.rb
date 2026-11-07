require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module Rails8FaceRecognition
  class Application < Rails::Application
    config.load_defaults 8.1
    # PostgreSQL triggers and functions are required for immutable face embeddings.
    # Ruby schema.rb cannot preserve them; use PostgreSQL structure.sql instead.
    config.active_record.schema_format = :sql
    # PostgreSQL administrators may install pgvector before the app connects.
    # Dumping extension comments would require the app role to own pgvector.
    config.after_initialize do
      ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = ["--no-comments"]
    end
    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "UTC"
    config.i18n.available_locales = [:en, :vi]
    config.i18n.default_locale = :en
    config.i18n.fallbacks = [:en]
    config.active_job.queue_adapter = :solid_queue
    config.action_dispatch.default_headers.merge!({ "X-Content-Type-Options" => "nosniff" })
    config.generators.system_tests = nil
  end
end
