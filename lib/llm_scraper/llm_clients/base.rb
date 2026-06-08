# frozen_string_literal: true

module LlmScraper
  module LlmClients
    class Base
      # Pricing in USD per 1M tokens (updated 2026-06)
      PRICING = {
        "deepseek-v4-flash"        => { input: 0.14, output: 0.28 },
        "deepseek-v4-pro"          => { input: 1.74, output: 3.48 },
        "kimi-k2.5"                => { input: 0.60, output: 3.00 },
        "glm-4.7-flash"            => { input: 0.0,  output: 0.0  },
        "claude-haiku-4-5"         => { input: 0.80, output: 4.00 },
        "claude-haiku-4-5-20251001" => { input: 0.80, output: 4.00 },
        "gemini-2.5-flash"         => { input: 0.15, output: 0.60 },
      }.freeze

      # @param prompt [String]
      # @return [Hash] { content: String, tokens: { input: Integer, output: Integer }, cost_usd: Float }
      # @raise [LlmScraper::LlmError]
      def complete(prompt)
        raise NotImplementedError, "#{self.class}#complete not implemented"
      end

      private

      def estimate_cost(model, input_tokens, output_tokens)
        pricing = PRICING[model] || { input: 0.0, output: 0.0 }
        (input_tokens * pricing[:input] + output_tokens * pricing[:output]) / 1_000_000.0
      end

      def build_connection(base_url:, timeout: 30)
        Faraday.new(url: base_url) do |f|
          f.request  :retry, max: 2, interval: 1, backoff_factor: 2,
                     retry_statuses: [429, 500, 502, 503, 504]
          f.options.timeout      = timeout
          f.options.open_timeout = 10
          f.adapter  Faraday.default_adapter
        end
      end
    end
  end
end
