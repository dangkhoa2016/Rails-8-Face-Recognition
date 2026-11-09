class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("EMAIL_FROM", "Rails 8 Face Recognition <no-reply@localhost>") }
  layout "mailer"
end
