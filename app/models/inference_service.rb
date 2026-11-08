require "ipaddr"
require "uri"

class InferenceService < ApplicationRecord
  has_many :embedding_models, dependent: :restrict_with_exception
  validates :name, presence: true, uniqueness: true
  validates :auth_secret_reference, presence: true, format: { with: /\A[A-Z][A-Z0-9_]+\z/ }
  validates :request_timeout_seconds, numericality: { only_integer: true, in: 30..600 }
  validate :https_public_url

  def secret_available?
    ENV[auth_secret_reference].present?
  end

  private

  def https_public_url
    uri = URI.parse(base_url.to_s)
    allowed = ENV.fetch("INFERENCE_ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:blank?)
    invalid = uri.scheme != "https" || uri.host.blank? || uri.userinfo.present? ||
              uri.query.present? || uri.fragment.present? || uri.host == "localhost" ||
              uri.host.end_with?(".local") || ![nil, "", "/"].include?(uri.path)
    # Explicit IP literals are refused (including loopback/link-local/metadata addresses).
    begin
      IPAddr.new(uri.host)
      invalid = true
    rescue IPAddr::InvalidAddressError
      # Hostname; DNS resolution and IP range checks are also required at request time.
    end
    if invalid
      errors.add(:base_url, "must be a public HTTPS host-only endpoint")
    elsif allowed.any? && !allowed.include?(uri.host)
      errors.add(:base_url, "hostname is not allowlisted")
    end
  rescue URI::InvalidURIError
    errors.add(:base_url, "is invalid")
  end
end
