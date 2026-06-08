# frozen_string_literal: true

module LlmScraper
  module ContentFetchers
    class Jina < Base
      BASE_URL = "https://r.jina.ai"

      def initialize(config = LlmScraper.configuration)
        @config = config
        @conn   = build_connection(base_url: BASE_URL, timeout: 30)
      end

      # @param url [String]
      # @return [String] markdown content
      def fetch(url)
        warn "[LlmScraper] No jina_api_key set — unauthenticated (~200 req/day limit)" if @config.jina_api_key.nil?

        response = @conn.get("/#{url}") do |req|
          req.headers["Accept"]        = "text/markdown"
          req.headers["Authorization"] = "Bearer #{@config.jina_api_key}" if @config.jina_api_key
        end

        raise LlmScraper::FetchError, "Jina error (#{response.status}): #{response.body}" unless response.success?

        response.body
      rescue Faraday::Error => e
        raise LlmScraper::FetchError, "Jina fetch error: #{e.message}"
      end
    end
  end
end
