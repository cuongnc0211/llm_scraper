# frozen_string_literal: true

module LlmScraper
  module ContentFetchers
    class Markdownify < Base
      BASE_URL = "https://api.scrapegraphai.com"

      def initialize(config = LlmScraper.configuration)
        @config = config
        @conn   = build_connection(base_url: BASE_URL, timeout: 60)
      end

      # @param url [String]
      # @return [String] markdown content
      def fetch(url)
        response = @conn.post("/v1/markdownify") do |req|
          req.headers["SGAI-APIKEY"]  = @config.markdownify_api_key
          req.headers["Content-Type"] = "application/json"
          req.body = JSON.generate(website_url: url)
        end

        raise LlmScraper::FetchError, "Markdownify error (#{response.status}): #{response.body}" unless response.success?

        body = JSON.parse(response.body)
        body["result"] ||
          raise(LlmScraper::FetchError, "Markdownify returned no content for #{url}")
      rescue Faraday::Error => e
        raise LlmScraper::FetchError, "Markdownify fetch error: #{e.message}"
      rescue JSON::ParserError => e
        raise LlmScraper::FetchError, "Markdownify response parse error: #{e.message}"
      end
    end
  end
end
