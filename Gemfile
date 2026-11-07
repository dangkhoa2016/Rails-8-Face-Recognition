source "https://rubygems.org"
ruby ">= 3.3.0"

gem "rails", "8.1.4.1"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "propshaft"
gem "tailwindcss-rails", "~> 4.0"
gem "turbo-rails"
gem "stimulus-rails"
gem "importmap-rails"
gem "bcrypt", "~> 3.1"
# Warden-backed authentication. Rate limiting remains database-backed.
gem "devise", "~> 5.0.4"
gem "neighbor", "~> 1.2"
gem "aws-sdk-s3", require: false
gem "solid_queue"
gem "bootsnap", require: false

group :development, :test do
  gem "debug"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "foreman"
end

group :test do
  gem "minitest-mock", "~> 5.27"
  gem "capybara"
  gem "selenium-webdriver"
end
# Lightweight image-header inspection before accepting private uploads.
gem "fastimage", "~> 2.4"
