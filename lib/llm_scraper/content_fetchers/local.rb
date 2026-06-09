# frozen_string_literal: true

module LlmScraper
  module ContentFetchers
    class Local < Base
      def initialize(config = LlmScraper.configuration)
        @config = config
      end

      # @param url [String]
      # @param spa [Boolean] use Ferrum for JS-rendered pages
      # @return [String] cleaned plain text
      def fetch(url, spa: false)
        spa ? fetch_spa(url) : fetch_static(url)
      end

      private

      def fetch_static(url)
        conn = build_connection(timeout: 30)
        response = conn.get(url)
        raise LlmScraper::FetchError, "HTTP #{response.status} for #{url}" unless response.success?

        clean_html(response.body)
      rescue Faraday::Error => e
        raise LlmScraper::FetchError, "Failed to fetch #{url}: #{e.message}"
      end

      def fetch_spa(url)
        begin
          require "ferrum"
        rescue LoadError
          raise LlmScraper::FetchError,
                "Ferrum gem required for SPA fetching. Add `gem 'ferrum'` to your Gemfile."
        end

        browser = Ferrum::Browser.new(headless: true)
        browser.go_to(url)
        browser.network.wait_for_idle
        html = browser.body
        browser.quit
        clean_html(html)
      rescue LlmScraper::FetchError
        raise
      rescue => e
        raise LlmScraper::FetchError, "SPA fetch failed for #{url}: #{e.message}"
      end

      # Strips boilerplate then converts to Markdown, preserving headings/tables/lists
      def clean_html(html)
        doc = Nokogiri::HTML(html)
        doc.css("script, style, nav, footer, header, [aria-hidden]").remove
        ReverseMarkdown.convert(doc.css("body").to_html, unknown_tags: :bypass)
      end
    end
  end
end
