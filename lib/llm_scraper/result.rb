# frozen_string_literal: true

module LlmScraper
  Result = Struct.new(
    :data,         # Hash — extracted fields
    :success,      # Boolean
    :error,        # String | nil
    :url,          # String | nil
    :fetcher,      # Symbol — fetcher used
    :provider,     # Symbol — LLM provider used
    :model,        # String — model name
    :tokens_used,  # Hash — { input: Integer, output: Integer }
    :cost_usd,     # Float — estimated cost
    :duration_ms,  # Integer — total time in milliseconds
    keyword_init: true
  ) do
    def success? = success
    def failure? = !success
  end
end
