require "vcr"

VCR.configure do |config|
  config.filter_sensitive_data("<SCRUBBED_OPENAI_API_KEY>") { ENV.fetch("OPENAI_API_KEY", nil) }
  config.filter_sensitive_data("<SCRUBBED_ANTHROPIC_API_KEY>") { ENV.fetch("ANTHROPIC_API_KEY", nil) }
  config.filter_sensitive_data("<SCRUBBED_OLLAMA_API_URL>") { ENV.fetch("OLLAMA_API_URL", nil) }
  config.filter_sensitive_data("<SCRUBBED_OLLAMA_API_KEY>") { ENV.fetch("OLLAMA_API_KEY", nil) }

  config.before_record do |interaction|
    if interaction.request.headers["Cookie"]
      interaction.request.headers["Cookie"] = ["<SCRUBBED>"]
    end
    if interaction.response.headers["Set-Cookie"]
      interaction.response.headers["Set-Cookie"] = ["<SCRUBBED>"]
    end
  end

  config.cassette_library_dir = "spec/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
end
