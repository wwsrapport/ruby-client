# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/wwsrapport"

class WwsrapportWebhooksTest < Minitest::Test
  def test_valid_signature
    payload = '{"type":"webhook.test"}'
    timestamp = "1710000000"
    signature = "v1=50ebb068d786d8e4b90f5c8d2f4d49a988df87705e9fa45eb761216e8e78c6a7"

    assert Wwsrapport::Webhooks.verify(
      payload: payload,
      timestamp: timestamp,
      signature: signature,
      secret: "whsec_test",
      now: Time.at(1_710_000_000)
    )
  end

  def test_invalid_signature
    refute Wwsrapport::Webhooks.verify(
      payload: '{"type":"webhook.test"}',
      timestamp: "1710000000",
      signature: "v1=bad",
      secret: "whsec_test",
      now: Time.at(1_710_000_000)
    )
  end
end
