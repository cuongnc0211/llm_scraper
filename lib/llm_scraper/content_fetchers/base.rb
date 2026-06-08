# frozen_string_literal: true

module LlmScraper
  module ContentFetchers
    class Base
      # @param url [String]
      # @return [String] cleaned text/markdown content
      # @raise [LlmScraper::FetchError]
      def fetch(url)
        raise NotImplementedError, "#{self.class}#fetch not implemented"
      end

      private

      def build_connection(base_url: nil, timeout: 30)
        Faraday.new(url: base_url) do |f|
          f.request  :retry, max: 3, interval: 1, backoff_factor: 2
          f.options.timeout      = timeout
          f.options.open_timeout = 10
          f.adapter  Faraday.default_adapter
        end
      end
    end
  end
end
