# WWSrapport Ruby Client

Official Ruby client for the WWSrapport Public API.

`derive_bag_reference`, `search_registry_by_bag` and `report_verification` expose the Solana attestation flow. `Wwsrapport::WEBHOOK_EVENTS` contains all 27 supported event types.

Use this SDK to create WWS reports, validate input, retrieve report JSON, download immutable PDF documents, recalculate a report with a chosen ruleset and manage webhooks.

## Installation

Add this line to your Gemfile:

```ruby
gem "wwsrapport"
```

Or install it directly:

```bash
gem install wwsrapport
```

## Quick start

```ruby
require "wwsrapport"

client = Wwsrapport::Client.new(api_key: ENV.fetch("WWSRAPPORT_API_KEY"))

report = client.create_report(
  {
    address: {
      postal_code: "3905RB",
      house_number: "4",
      city: "Veenendaal"
    },
    input: {
      living_area_m2: 53,
      energy_label: "E"
    }
  },
  idempotency_key: "crm-report-3905rb-4-2026-01"
)

puts report["id"]
```

## Recalculate an existing report

```ruby
result = client.recalculate_report(
  "rpt_example",
  { rule_version: "latest", refresh_sources: false },
  idempotency_key: "crm-report-3905rb-4-recalculate-latest"
)
```

## Download documents

```ruby
File.binwrite("wws-report.pdf", client.download_wws_report("rpt_example"))
File.binwrite("improvement-advice.pdf", client.download_improvement_advice("rpt_example"))
```

## Webhook verification

```ruby
valid = Wwsrapport::Webhooks.verify(
  payload: request.body.read,
  timestamp: request.get_header("HTTP_WWSRAPPORT_TIMESTAMP"),
  signature: request.get_header("HTTP_WWSRAPPORT_SIGNATURE"),
  secret: ENV.fetch("WWSRAPPORT_WEBHOOK_SECRET")
)
```

Webhook signatures are HMAC-SHA256 values over:

```text
{timestamp}.{raw_request_body}
```

## API coverage

- `POST /v1/properties/prefill`
- `POST /v1/reports/validate`
- `POST /v1/reports`
- `POST /v1/reports/{id}/recalculate`
- `GET /v1/reports`
- `GET /v1/reports/{id}`
- `GET /v1/reports/{id}/calculation`
- `GET /v1/reports/{id}/improvement-advice`
- `GET /v1/reports/{id}/documents`
- `GET /v1/reports/{id}/documents/wws-report`
- `GET /v1/reports/{id}/documents/improvement-advice`
- `GET /v1/usage/current`
- `GET /v1/usage/history`
- `GET /v1/rulesets`
- `GET /v1/webhooks`
- `POST /v1/webhooks`
- `GET /v1/webhooks/{id}`
- `PATCH /v1/webhooks/{id}`
- `DELETE /v1/webhooks/{id}`
- `POST /v1/webhooks/{id}/test`
- `GET /v1/webhooks/{id}/deliveries`
- `POST /v1/webhooks/{id}/deliveries/{delivery_id}/retry`

## Links

- API documentation: https://wwsrapport.nl/api/docs
- OpenAPI: https://wwsrapport.nl/api/openapi.json
- API access: https://wwsrapport.nl/api/toegang-aanvragen

## License

MIT
