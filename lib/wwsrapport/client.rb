# frozen_string_literal: true

require "json"
require "net/http"
require "securerandom"
require "uri"

module Wwsrapport
  class Client
    DEFAULT_BASE_URL = "https://wwsrapport.nl/v1"
    CLIENT_HEADER = "wwsrapport-ruby-client/0.3.0"

    def initialize(api_key: nil, oauth: nil, request_context: nil, base_url: DEFAULT_BASE_URL, http: Net::HTTP)
      raise ArgumentError, "api_key or oauth client credentials are required" if api_key.to_s.strip.empty? && oauth.nil?

      @api_key = api_key
      @oauth = oauth
      @request_context = request_context || {}
      @base_url = base_url.to_s.sub(%r{/+\z}, "")
      @http = http
      @token_mutex = Mutex.new
      @access_token = nil
      @token_expires_at = Time.at(0)
    end

    def prefill_property(address)
      post_json("/properties/prefill", { address: address })
    end

    def validate_report(input)
      post_json("/reports/validate", input)
    end

    def create_report(input, idempotency_key:)
      post_json("/reports", input, idempotency_key: idempotency_key)
    end

    def recalculate_report(report_id, input = {}, idempotency_key:)
      post_json("/reports/#{escape(report_id)}/recalculate", input, idempotency_key: idempotency_key)
    end

    def reports(query = {})
      get_json("/reports", query: query)
    end

    def report(report_id)
      get_json("/reports/#{escape(report_id)}")
    end

    def calculation(report_id)
      get_json("/reports/#{escape(report_id)}/calculation")
    end

    def improvement_advice(report_id)
      get_json("/reports/#{escape(report_id)}/improvement-advice")
    end

    def report_verification(report_id)
      get_json("/reports/#{escape(report_id)}/verification")
    end

    def review_report(report_id, review, idempotency_key:)
      post_json("/reports/#{escape(report_id)}/human-review", review, idempotency_key: idempotency_key)
    end

    def create_batch(input, idempotency_key:)
      post_json("/batches", input, idempotency_key: idempotency_key)
    end

    def batch(id)
      get_json("/batches/#{escape(id)}")
    end

    def retry_batch(id, idempotency_key:)
      post_json("/batches/#{escape(id)}/retry", nil, idempotency_key: idempotency_key)
    end

    def request_tenant_export(idempotency_key:)
      post_json("/exports", nil, idempotency_key: idempotency_key)
    end

    def tenant_export(id)
      get_json("/exports/#{escape(id)}")
    end

    def tenant_export_download_url(id)
      post_json("/exports/#{escape(id)}/download-url", nil)
    end
    def request_offboarding(requested_by_reference, reason: nil)
      post_json("/offboarding", { confirmation: "REQUEST_OFFBOARDING", requested_by_reference: requested_by_reference, reason: reason })
    end

    def derive_bag_reference(bag_vbo_id)
      validate_bag_vbo_id!(bag_vbo_id)
      post_json("/registry/bag-reference", { bagVboId: bag_vbo_id })
    end

    def search_registry_by_bag(bag_vbo_id)
      validate_bag_vbo_id!(bag_vbo_id)
      post_json("/registry/search-by-bag", { bagVboId: bag_vbo_id })
    end

    def documents(report_id)
      get_json("/reports/#{escape(report_id)}/documents")
    end

    def download_wws_report(report_id)
      get_bytes("/reports/#{escape(report_id)}/documents/wws-report")
    end

    def download_improvement_advice(report_id)
      get_bytes("/reports/#{escape(report_id)}/documents/improvement-advice")
    end

    def current_usage
      get_json("/usage/current")
    end

    def usage_history(query = {})
      get_json("/usage/history", query: query)
    end

    def rulesets
      get_json("/rulesets")
    end

    def webhooks
      get_json("/webhooks")
    end

    def create_webhook(input)
      post_json("/webhooks", input)
    end

    def webhook(webhook_id)
      get_json("/webhooks/#{escape(webhook_id)}")
    end

    def update_webhook(webhook_id, input)
      request_json("PATCH", "/webhooks/#{escape(webhook_id)}", input)
    end

    def delete_webhook(webhook_id)
      request_json("DELETE", "/webhooks/#{escape(webhook_id)}")
    end

    def send_test_webhook(webhook_id)
      post_json("/webhooks/#{escape(webhook_id)}/test", nil)
    end

    def webhook_deliveries(webhook_id, query = {})
      get_json("/webhooks/#{escape(webhook_id)}/deliveries", query: query)
    end

    def retry_webhook_delivery(webhook_id, delivery_id)
      post_json("/webhooks/#{escape(webhook_id)}/deliveries/#{escape(delivery_id)}/retry", nil)
    end

    private

    def validate_bag_vbo_id!(value)
      raise ArgumentError, "BAG verblijfsobject ID must contain exactly sixteen digits." unless value.to_s.match?(/\A[0-9]{16}\z/)
    end

    def get_json(path, query: {})
      request_json("GET", path, query: query)
    end

    def post_json(path, body, idempotency_key: nil)
      request_json("POST", path, body, idempotency_key: idempotency_key)
    end

    def request_json(method, path, body = nil, query: {}, idempotency_key: nil)
      response = request(method, path, body: body, query: query, idempotency_key: idempotency_key, accept: "application/json")
      response.body.nil? || response.body.empty? ? {} : JSON.parse(response.body)
    end

    def get_bytes(path)
      request("GET", path, accept: "application/pdf, application/octet-stream").body
    end

    def request(method, path, body: nil, query: {}, idempotency_key: nil, accept: "application/json")
      uri = uri_for(path, query)
      request = build_request(method, uri, body, accept, idempotency_key)
      response = @http.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |connection|
        connection.request(request)
      end

      raise Error.from_response(response) unless response.is_a?(Net::HTTPSuccess)

      response
    end

    def build_request(method, uri, body, accept, idempotency_key)
      klass = Net::HTTP.const_get(method.capitalize)
      request = klass.new(uri)
      request["Accept"] = accept
      request["Authorization"] = "Bearer #{bearer_token}"
      request["X-WWSrapport-Client"] = CLIENT_HEADER
      context_headers.each { |name, value| request[name] = value }
      request["Idempotency-Key"] = idempotency_key if idempotency_key

      unless body.nil?
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(body)
      end

      request
    end

    def bearer_token
      return @api_key unless @api_key.to_s.strip.empty?

      @token_mutex.synchronize do
        return @access_token if @access_token && Time.now + 30 < @token_expires_at

        token_uri = URI(@oauth[:token_url] || "#{URI(@base_url).scheme}://#{URI(@base_url).host}#{URI(@base_url).port == 443 ? '' : ":#{URI(@base_url).port}"}/oauth/token")
        token_request = Net::HTTP::Post.new(token_uri)
        token_request.basic_auth(@oauth.fetch(:client_id), @oauth.fetch(:client_secret))
        token_request["Accept"] = "application/json"
        token_request.set_form_data(grant_type: "client_credentials", scope: Array(@oauth[:scopes]).join(" "))
        response = @http.start(token_uri.hostname, token_uri.port, use_ssl: token_uri.scheme == "https") { |connection| connection.request(token_request) }
        raise Error.from_response(response) unless response.is_a?(Net::HTTPSuccess)
        payload = JSON.parse(response.body)
        @access_token = payload.fetch("access_token")
        @token_expires_at = Time.now + payload.fetch("expires_in", 300).to_i
        @access_token
      end
    end

    def context_headers
      {
        "X-WWS-Municipality-Code" => @request_context[:municipality_code],
        "X-WWS-Purpose-Code" => @request_context[:purpose_code],
        "X-WWS-Case-Reference" => @request_context[:case_reference],
        "X-WWS-Client-Reference" => @request_context[:client_reference]
      }.reject { |_name, value| value.to_s.strip.empty? }
    end

    def uri_for(path, query)
      uri = URI("#{@base_url}/#{path.to_s.sub(%r{\A/+}, "")}")
      filtered_query = query.reject { |_key, value| value.nil? || value.to_s.empty? }
      uri.query = URI.encode_www_form(filtered_query) unless filtered_query.empty?
      uri
    end

    def escape(value)
      URI.encode_www_form_component(value.to_s)
    end
  end
end
