class AuthThrottle < ApplicationRecord
  validates :key_hash, presence: true # Database unique index guards create_or_find_by! under concurrency.
end
