# frozen_string_literal: true

require "openssl"

module Wwsrapport
  module Webhooks
    module_function

    def verify(payload:, timestamp:, signature:, secret:, tolerance_seconds: 300, now: Time.now)
      return false if payload.to_s.empty? || timestamp.to_s.empty? || signature.to_s.empty? || secret.to_s.empty?

      timestamp_i = Integer(timestamp)
      return false if (now.to_i - timestamp_i).abs > tolerance_seconds

      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
      signatures(signature).any? { |candidate| secure_compare(candidate, expected) }
    rescue ArgumentError
      false
    end

    def signatures(header)
      header.to_s.split(",").map do |part|
        key, value = part.split("=", 2)
        value if key == "v1" && value && !value.empty?
      end.compact
    end

    def secure_compare(left, right)
      return false unless left.bytesize == right.bytesize

      left.bytes.zip(right.bytes).reduce(0) { |acc, pair| acc | (pair[0] ^ pair[1]) }.zero?
    end
  end
end
