# frozen_string_literal: true

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.default_cassette_options = { record: :new_episodes }

  # Scrub API keys from recorded cassettes
  config.filter_sensitive_data("<JINA_API_KEY>")       { ENV["JINA_API_KEY"] }
  config.filter_sensitive_data("<DEEPSEEK_API_KEY>")   { ENV["DEEPSEEK_API_KEY"] }
  config.filter_sensitive_data("<ANTHROPIC_API_KEY>")  { ENV["ANTHROPIC_API_KEY"] }
  config.filter_sensitive_data("<GLM_API_KEY>")        { ENV["GLM_API_KEY"] }
  config.filter_sensitive_data("<FIRECRAWL_API_KEY>")  { ENV["FIRECRAWL_API_KEY"] }
end
