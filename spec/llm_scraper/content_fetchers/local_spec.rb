# frozen_string_literal: true

RSpec.describe LlmScraper::ContentFetchers::Local do
  let(:fetcher) { described_class.new }
  let(:sample_html) { File.read(File.join(__dir__, "../../fixtures/sample.html")) }

  describe "#fetch" do
    it "fetches and strips boilerplate HTML", :vcr do
      stub_request(:get, "https://example.com/artist")
        .to_return(status: 200, body: sample_html, headers: { "Content-Type" => "text/html" })

      result = fetcher.fetch("https://example.com/artist")

      expect(result).to include("顾景舟")
      expect(result).to include("zisha")
      expect(result).not_to include("<script>")
      expect(result).not_to include("<nav>")
      expect(result).not_to include("<footer>")
    end

    it "raises FetchError on HTTP error" do
      stub_request(:get, "https://example.com/bad").to_return(status: 404, body: "Not Found")

      expect { fetcher.fetch("https://example.com/bad") }
        .to raise_error(LlmScraper::FetchError, /HTTP 404/)
    end

    it "raises FetchError on network error" do
      stub_request(:get, "https://example.com/timeout").to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { fetcher.fetch("https://example.com/timeout") }
        .to raise_error(LlmScraper::FetchError, /connection refused/)
    end

    it "raises FetchError with helpful message when ferrum missing for SPA" do
      allow(fetcher).to receive(:require).with("ferrum").and_raise(LoadError)

      expect { fetcher.fetch("https://example.com", spa: true) }
        .to raise_error(LlmScraper::FetchError, /Ferrum gem required/)
    end
  end
end
