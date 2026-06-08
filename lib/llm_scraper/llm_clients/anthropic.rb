# frozen_string_literal: true

module LlmScraper
  module LlmClients
    class Anthropic < Base
      BASE_URL    = "https://api.anthropic.com"
      API_VERSION = "2023-06-01"

      def initialize(config = LlmScraper.configuration)
        @config = config
        @conn   = build_connection(base_url: BASE_URL, timeout: config.llm_timeout)
      end

      # @param prompt [String]
      # @return [Hash] { content:, tokens:, cost_usd: }
      def complete(prompt)
        response = @conn.post("v1/messages") do |req|
          req.headers["x-api-key"]        = @config.llm_api_key
          req.headers["anthropic-version"] = API_VERSION
          req.headers["Content-Type"]      = "application/json"
          req.body = JSON.generate(
            model:      @config.llm_model,
            max_tokens: 1024,
            messages:   [{ role: "user", content: prompt }]
          )
        end

        handle_response(response)
      rescue Faraday::Error => e
        raise LlmScraper::LlmError, "Anthropic request failed: #{e.message}"
      end

      private

      def handle_response(response)
        raise LlmScraper::LlmError, "Anthropic API error #{response.status}: #{response.body}" unless response.success?

        body          = JSON.parse(response.body)
        content       = body.dig("content", 0, "text")
        input_tokens  = body.dig("usage", "input_tokens").to_i
        output_tokens = body.dig("usage", "output_tokens").to_i

        {
          content:  content,
          tokens:   { input: input_tokens, output: output_tokens },
          cost_usd: estimate_cost(@config.llm_model, input_tokens, output_tokens)
        }
      rescue JSON::ParserError => e
        raise LlmScraper::LlmError, "Failed to parse Anthropic response: #{e.message}"
      end
    end
  end
end
