# Delay resolving app/services/EmailDelivery until Rails' main autoloader is ready.
Rails.application.config.after_initialize do
  EmailDelivery.configure!(Rails.application.config)
end
