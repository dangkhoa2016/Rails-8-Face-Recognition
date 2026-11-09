class DatasetImportJob < ApplicationJob
  queue_as :default

  def perform(import_id)
    record = DatasetImport.find(import_id)
    DatasetImports::VerifiedSnapshot.call(record)
  rescue DatasetImports::VerifiedSnapshot::InvalidSnapshot, ActiveRecord::RecordInvalid, Errno::ENOENT => error
    record&.update!(import_status: "failed", finished_at: Time.current, error_summary: error.message.first(240))
  rescue StandardError => error
    record&.update!(import_status: "failed", finished_at: Time.current, error_summary: "Import failed; check server logs for the error category.")
    Rails.logger.error("Dataset import error class=#{error.class.name} import_id=#{import_id}")
  end
end
