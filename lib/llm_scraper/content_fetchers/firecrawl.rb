# frozen_string_literal: true

module LlmScraper
  module ContentFetchers
    class Firecrawl < Base
      BASE_URL = "https://api.firecrawl.dev"

      def initialize(config = LlmScraper.configuration)
        @config = config
        @conn   = build_connection(base_url: BASE_URL, timeout: 60)
      end

      # @param url [String]
      # @return [String] markdown content
      def fetch(url)
        response = @conn.post("/v1/scrape") do |req|
          req.headers["Authorization"] = "Bearer #{@config.firecrawl_api_key}"
          req.headers["Content-Type"]  = "application/json"
          req.body = JSON.generate(url: url, formats: ["markdown"])
        end

        raise LlmScraper::FetchError, "Firecrawl error (#{response.status}): #{response.body}" unless response.success?

        body = JSON.parse(response.body)
        body.dig("data", "markdown") ||
          raise(LlmScraper::FetchError, "Firecrawl returned no markdown for #{url}")
      rescue Faraday::Error => e
        raise LlmScraper::FetchError, "Firecrawl fetch error: #{e.message}"
      rescue JSON::ParserError => e
        raise LlmScraper::FetchError, "Firecrawl response parse error: #{e.message}"
      end
    end
  end
end
