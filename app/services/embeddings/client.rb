require "base64"
require "securerandom"
require "openssl"
require "digest"
require "ipaddr"
require "json"
require "net/http"
require "resolv"
require "uri"

module Embeddings
  class Client
    class Error < StandardError
      attr_reader :code
      def initialize(code)
        @code = code.to_s
        super("Inference request failed (#{@code})")
      end
    end

    BLOCKED_NETWORKS = %w[
      0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
      172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16
      198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
      ::/128 ::1/128 fc00::/7 fe80::/10 ff00::/8 2001:db8::/32
    ].map { |ip| IPAddr.new(ip) }.freeze

    def initialize(service)
      @service = service
    end

    def models
      request(:get, "/v1/models")
    end

    def embed(image_bytes:, profile:)
      raise Error, "image_too_large" if image_bytes.bytesize > ImageUploads::Validate::MAX_BYTES
      raise Error, "model_disabled" unless profile.embedding_model.enabled? && @service.enabled?
      body = {
        model: profile.embedding_model.api_model_id,
        dimension: profile.dimension,
        image_base64: Base64.strict_encode64(image_bytes),
        request_id: SecureRandom.uuid
      }
      body[:instruction] = profile.instruction if profile.instruction.present?
      response = request(:post, "/v1/embeddings", body)
      validate_response!(response, profile, Digest::SHA256.hexdigest(image_bytes))
      response
    end

    private

    def request(method, path, body = nil)
      token = ENV[@service.auth_secret_reference]
      raise Error, "token_missing" if token.blank?
      uri = URI.parse(@service.base_url)
      hosts = ENV.fetch("INFERENCE_ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:blank?)
      raise Error, "hostname_not_allowlisted" if hosts.empty? || !hosts.include?(uri.host)
      raise Error, "invalid_endpoint" unless uri.scheme == "https" && uri.port == 443 && uri.path.in?(["", "/"]) && uri.userinfo.nil?

      addresses = Resolv.getaddresses(uri.host)
      raise Error, "dns_rejected" if addresses.empty?
      resolved = addresses.map { |ip| IPAddr.new(ip) }
      raise Error, "dns_rejected" if resolved.any? { |ip| BLOCKED_NETWORKS.any? { |network| network.include?(ip) } }
      http = Net::HTTP.new(uri.host, 443)
      http.ipaddr = resolved.first.to_s # Pin the validated IP against DNS rebinding.
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = @service.request_timeout_seconds
      http.write_timeout = 30
      http.max_retries = 0
      request = method == :get ? Net::HTTP::Get.new(path) : Net::HTTP::Post.new(path)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(body) if body
      response = http.request(request)
      code = response.code.to_i
      raise Error, "http_#{code}" unless code == 200
      raise Error, "response_too_large" if response.body.to_s.bytesize > 1_000_000
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "invalid_json"
    rescue Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
      raise Error, "timeout"
    rescue OpenSSL::SSL::SSLError
      raise Error, "tls_failed"
    rescue SocketError, SystemCallError, Resolv::ResolvError
      raise Error, "network_failed"
    end

    def validate_response!(response, profile, input_sha)
      raise Error, "invalid_response" unless response.is_a?(Hash)
      metadata = response["embedding_metadata"]
      raise Error, "missing_metadata" unless metadata.is_a?(Hash)
      unless response["model"] == profile.embedding_model.api_model_id &&
             response["dimension"] == profile.dimension &&
             response["revision"] == profile.model_revision &&
             response["input_sha256"] == input_sha &&
             metadata["preprocessing_version"] == profile.preprocessing_version &&
             response["normalized"] == true
        raise Error, "configuration_drift"
      end
      if metadata["config_sha256"] !~ /\A[0-9a-f]{64}\z/ ||
         profile.config_sha256.present? && profile.config_sha256 != metadata["config_sha256"] ||
         profile.instruction_sha256.present? && profile.instruction_sha256 != metadata["instruction_sha256"]
        raise Error, "configuration_drift"
      end
      unless metadata["instruction_sha256"].nil? || metadata["instruction_sha256"].match?(/\A[0-9a-f]{64}\z/)
        raise Error, "invalid_instruction_hash"
      end
      vector = response["vector"]
      unless vector.is_a?(Array) && vector.length == profile.dimension && vector.all? { |v| v.is_a?(Numeric) && v.finite? }
        raise Error, "invalid_vector"
      end
      norm = Math.sqrt(vector.sum { |v| v.to_f * v.to_f })
      raise Error, "invalid_vector_norm" if (norm - 1).abs > 0.01
    end
  end
end
