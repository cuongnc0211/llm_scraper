# frozen_string_literal: true

module LlmScraper
  class Configuration
    attr_accessor :llm_provider      # :openai_compatible | :anthropic
    attr_accessor :llm_base_url      # e.g. "https://api.deepseek.com/v1"
    attr_accessor :llm_api_key
    attr_accessor :llm_model         # e.g. "deepseek-v4-flash"
    attr_accessor :llm_timeout       # seconds
    attr_accessor :max_retries

    attr_accessor :fetcher            # :jina | :firecrawl | :markdownify | :local
    attr_accessor :jina_api_key       # nil = unauthenticated (~200 req/day limit)
    attr_accessor :firecrawl_api_key
    attr_accessor :markdownify_api_key

    def initialize
      @llm_provider = :openai_compatible
      @llm_timeout  = 30
      @max_retries  = 3
      @fetcher      = :jina
    end
  end
end
