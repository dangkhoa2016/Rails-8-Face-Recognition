class DataReset < ApplicationRecord
  SCOPES = %w[mine all_test_activity probe_cache].freeze
  STATUSES = %w[pending running completed failed].freeze
  belongs_to :actor, class_name: "User"
  validates :scope, inclusion: { in: SCOPES }
  validates :status, inclusion: { in: STATUSES }
  validates :cutoff_at, presence: true
end
