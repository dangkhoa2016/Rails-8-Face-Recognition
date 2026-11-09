class PurgeExpiredSubmissionsJob < ApplicationJob
  queue_as :default

  def perform
    FaceImage.expirable_submissions.find_each { |image| Submissions::Purge.call(image) }
  end
end
