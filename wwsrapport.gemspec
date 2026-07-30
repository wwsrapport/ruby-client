# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "wwsrapport"
  spec.version = "0.1.0"
  spec.authors = ["WWSrapport"]
  spec.email = ["api@wwsrapport.nl"]

  spec.summary = "Ruby client for the WWSrapport Public API"
  spec.description = "Create WWS reports, retrieve report JSON and PDFs, recalculate reports and verify WWSrapport webhooks."
  spec.homepage = "https://wwsrapport.nl/api/docs"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/wwsrapport/ruby-client",
    "documentation_uri" => "https://wwsrapport.nl/api/docs"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]
end
