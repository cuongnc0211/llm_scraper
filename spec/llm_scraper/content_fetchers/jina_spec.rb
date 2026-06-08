# frozen_string_literal: true

RSpec.describe LlmScraper::ContentFetchers::Jina do
  let(:config) do
    LlmScraper::Configuration.new.tap do |c|
      c.fetcher      = :jina
      c.jina_api_key = "test-jina-key"
    end
  end

  let(:fetcher) { described_class.new(config) }
  let(:target_url) { "https://example.com/article" }
  let(:markdown_content) { "# Example Article\n\nContent here." }

  describe "#fetch" do
    it "returns markdown content on success" do
      stub_request(:get, "https://r.jina.ai/#{target_url}")
        .to_return(status: 200, body: markdown_content)

      result = fetcher.fetch(target_url)

      expect(result).to eq(markdown_content)
    end

    it "sends Authorization header when api_key is present" do
      stub = stub_request(:get, "https://r.jina.ai/#{target_url}")
        .with(headers: { "Authorization" => "Bearer test-jina-key" })
        .to_return(status: 200, body: markdown_content)

      fetcher.fetch(target_url)

      expect(stub).to have_been_requested
    end

    it "omits Authorization header when no api_key" do
      config.jina_api_key = nil
      no_key_fetcher = described_class.new(config)

      stub = stub_request(:get, "https://r.jina.ai/#{target_url}")
        .with(headers: { "Accept" => "text/markdown" })
        .to_return(status: 200, body: markdown_content)

      expect { no_key_fetcher.fetch(target_url) }.to output(/No jina_api_key/).to_stderr

      expect(stub).to have_been_requested
    end

    it "raises FetchError on HTTP error" do
      stub_request(:get, "https://r.jina.ai/#{target_url}")
        .to_return(status: 429, body: "Too Many Requests")

      expect { fetcher.fetch(target_url) }
        .to raise_error(LlmScraper::FetchError, /429/)
    end

    it "raises FetchError on network failure" do
      stub_request(:get, "https://r.jina.ai/#{target_url}")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { fetcher.fetch(target_url) }
        .to raise_error(LlmScraper::FetchError, /connection refused/)
    end
  end
end
