# frozen_string_literal: true

module Wwsrapport
  class Error < StandardError
    attr_reader :status, :request_id, :body

    def self.from_response(response)
      new(
        "WWSrapport API returned HTTP #{response.code}: #{response.body}",
        status: response.code.to_i,
        request_id: response["X-Request-Id"],
        body: response.body
      )
    end

    def initialize(message, status: nil, request_id: nil, body: nil)
      super(message)
      @status = status
      @request_id = request_id
      @body = body
    end
  end
end
