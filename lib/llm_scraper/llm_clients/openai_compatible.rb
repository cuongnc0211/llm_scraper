# frozen_string_literal: true

module LlmScraper
  module LlmClients
    class OpenaiCompatible < Base
      def initialize(config = LlmScraper.configuration)
        @config = config
        @conn   = build_connection(base_url: config.llm_base_url, timeout: config.llm_timeout)
      end

      # @param prompt [String]
      # @return [Hash] { content:, tokens:, cost_usd: }
      def complete(prompt)
        response = @conn.post("chat/completions") do |req|
          req.headers["Authorization"] = "Bearer #{@config.llm_api_key}"
          req.headers["Content-Type"]  = "application/json"
          req.body = JSON.generate(
            model:           @config.llm_model,
            messages:        [{ role: "user", content: prompt }],
            temperature:     0,
            response_format: { type: "json_object" }
          )
        end

        handle_response(response)
      rescue Faraday::Error => e
        raise LlmScraper::LlmError, "LLM request failed: #{e.message}"
      end

      private

      def handle_response(response)
        raise LlmScraper::LlmError, "LLM API error #{response.status}: #{response.body}" unless response.success?

        body          = JSON.parse(response.body)
        content       = body.dig("choices", 0, "message", "content")
        input_tokens  = body.dig("usage", "prompt_tokens").to_i
        output_tokens = body.dig("usage", "completion_tokens").to_i

        {
          content:  content,
          tokens:   { input: input_tokens, output: output_tokens },
          cost_usd: estimate_cost(@config.llm_model, input_tokens, output_tokens)
        }
      rescue JSON::ParserError => e
        raise LlmScraper::LlmError, "Failed to parse LLM response: #{e.message}"
      end
    end
  end
end
