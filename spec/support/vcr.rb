require "vcr"

VCR.configure do |config|
  config.filter_sensitive_data("<SCRUBBED_OPENAI_API_KEY>") { ENV.fetch("OPENAI_API_KEY", nil) }
  config.filter_sensitive_data("<SCRUBBED_ANTHROPIC_API_KEY>") { ENV.fetch("ANTHROPIC_API_KEY", nil) }
  config.filter_sensitive_data("<SCRUBBED_OLLAMA_API_URL>") { ENV.fetch("OLLAMA_API_URL", nil) }

  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
end
