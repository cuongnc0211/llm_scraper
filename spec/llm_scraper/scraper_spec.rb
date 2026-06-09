# frozen_string_literal: true

RSpec.describe LlmScraper::Scraper do
  let(:schema) do
    LlmScraper::Schema.define do
      field :name,  type: :string, required: true, description: "Artisan name"
      field :price, type: :number, description: "Price in CNY"
    end
  end

  let(:config) do
    LlmScraper::Configuration.new.tap do |c|
      c.llm_provider = :openai_compatible
      c.llm_base_url = "https://api.deepseek.com/v1"
      c.llm_api_key  = "test-key"
      c.llm_model    = "deepseek-v4-flash"
      c.fetcher      = :jina
      c.jina_api_key = "test-jina-key"
    end
  end

  let(:scraper) { described_class.new(schema: schema, config: config) }

  let(:llm_response_body) do
    JSON.generate(
      choices: [{ message: { content: '{"name":"Gu Jingzhou","price":15000}' } }],
      usage: { prompt_tokens: 500, completion_tokens: 30 }
    )
  end

  describe "#extract" do
    it "extracts structured data from raw content" do
      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 200, body: llm_response_body, headers: { "Content-Type" => "application/json" })

      result = scraper.extract("Some markdown content about Gu Jingzhou")

      expect(result).to be_success
      expect(result.data[:name]).to eq("Gu Jingzhou")
      expect(result.data[:price]).to eq(15000)
      expect(result.tokens_used).to eq({ input: 500, output: 30 })
      expect(result.cost_usd).to be_a(Float)
      expect(result.duration_ms).to be_a(Integer)
    end

    it "returns Result with correct provider and model metadata" do
      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 200, body: llm_response_body, headers: { "Content-Type" => "application/json" })

      result = scraper.extract("content")

      expect(result.provider).to eq(:openai_compatible)
      expect(result.model).to eq("deepseek-v4-flash")
    end
  end

  describe "#scrape" do
    it "fetches URL then extracts structured data" do
      stub_request(:get, "https://r.jina.ai/https://example.com/teapot")
        .to_return(status: 200, body: "# Teapot page content")

      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 200, body: llm_response_body, headers: { "Content-Type" => "application/json" })

      result = scraper.scrape("https://example.com/teapot")

      expect(result).to be_success
      expect(result.url).to eq("https://example.com/teapot")
      expect(result.fetcher).to eq(:jina)
      expect(result.data[:name]).to eq("Gu Jingzhou")
    end

    it "raises FetchError when fetch fails (rescue_errors: false)" do
      stub_request(:get, "https://r.jina.ai/https://example.com/teapot")
        .to_return(status: 503, body: "Service Unavailable")

      expect { scraper.scrape("https://example.com/teapot") }
        .to raise_error(LlmScraper::FetchError)
    end

    it "returns failure Result when rescue_errors: true" do
      stub_request(:get, "https://r.jina.ai/https://example.com/teapot")
        .to_return(status: 503, body: "Service Unavailable")

      result = scraper.scrape("https://example.com/teapot", rescue_errors: true)

      expect(result).to be_failure
      expect(result.error).to match(/503/)
    end
  end

  describe "#scrape_batch" do
    it "returns array of results without raising" do
      stub_request(:get, %r{https://r\.jina\.ai/https://example\.com/.*})
        .to_return(status: 200, body: "# Content")

      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 200, body: llm_response_body, headers: { "Content-Type" => "application/json" })

      urls = ["https://example.com/a", "https://example.com/b"]
      results = scraper.scrape_batch(urls)

      expect(results.length).to eq(2)
      expect(results).to all(be_a(LlmScraper::Result))
    end

    it "captures errors per item without raising" do
      stub_request(:get, "https://r.jina.ai/https://example.com/good")
        .to_return(status: 200, body: "# Good page")
      stub_request(:get, "https://r.jina.ai/https://example.com/bad")
        .to_return(status: 500, body: "Error")

      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 200, body: llm_response_body, headers: { "Content-Type" => "application/json" })

      results = scraper.scrape_batch(["https://example.com/good", "https://example.com/bad"])

      expect(results.first).to be_success
      expect(results.last).to be_failure
    end
  end

  describe "#with_provider" do
    it "returns new Scraper with swapped provider" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(
          status: 200,
          body: JSON.generate(
            content: [{ text: '{"name":"Gu Jingzhou","price":15000}' }],
            usage: { input_tokens: 500, output_tokens: 30 }
          ),
          headers: { "Content-Type" => "application/json" }
        )

      config.llm_api_key = "test-anthropic-key"
      anthropic_scraper = scraper.with_provider(:anthropic)
      result = anthropic_scraper.extract("content")

      expect(result.provider).to eq(:anthropic)
      expect(result).to be_success
    end
  end

  describe "#scrape with spa: true" do
    it "forwards spa: true to local fetcher" do
      local_config = config.dup.tap { |c| c.fetcher = :local }
      local_scraper = described_class.new(schema: schema, config: local_config)

      fetcher_double = instance_double(LlmScraper::ContentFetchers::Local)
      allow(LlmScraper::ContentFetchers::Local).to receive(:new).and_return(fetcher_double)
      allow(fetcher_double).to receive(:fetch).with("https://example.com/spa", spa: true).and_return("# SPA content")

      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 200, body: llm_response_body, headers: { "Content-Type" => "application/json" })

      result = local_scraper.scrape("https://example.com/spa", spa: true)

      expect(fetcher_double).to have_received(:fetch).with("https://example.com/spa", spa: true)
      expect(result).to be_success
    end

    it "does not forward spa: to non-local fetchers" do
      jina_scraper = described_class.new(schema: schema, config: config)

      stub_request(:get, "https://r.jina.ai/https://example.com/page")
        .to_return(status: 200, body: "# Content")
      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 200, body: llm_response_body, headers: { "Content-Type" => "application/json" })

      expect { jina_scraper.scrape("https://example.com/page", spa: true) }.not_to raise_error
    end
  end

  describe "#with_fetcher" do
    it "returns new Scraper with swapped fetcher" do
      html = "<html><body><h1>Gu Jingzhou teapot</h1></body></html>"
      stub_request(:get, "https://example.com/teapot")
        .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })

      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 200, body: llm_response_body, headers: { "Content-Type" => "application/json" })

      local_scraper = scraper.with_fetcher(:local)
      result = local_scraper.scrape("https://example.com/teapot")

      expect(result.fetcher).to eq(:local)
      expect(result).to be_success
    end
  end

  describe "parse retry" do
    it "retries with stricter prompt on ParseError then returns result" do
      bad_json  = "Sure! Here is the JSON:\n```json\n{\"name\":\"Gu\"}\n```"
      good_json = '{"name":"Gu Jingzhou","price":15000}'

      call_count = 0
      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return do
          call_count += 1
          body = call_count == 1 ? bad_json : good_json
          {
            status: 200,
            body: JSON.generate(
              choices: [{ message: { content: body } }],
              usage: { prompt_tokens: 100, completion_tokens: 10 }
            ),
            headers: { "Content-Type" => "application/json" }
          }
        end

      result = scraper.extract("content")

      expect(result).to be_success
      expect(result.data[:name]).to eq("Gu Jingzhou")
      expect(call_count).to eq(2)
    end
  end

  describe "schema from Hash" do
    it "accepts Hash schema" do
      hash_schema = {
        name: { type: :string, required: true, description: "Name" }
      }

      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(
          status: 200,
          body: JSON.generate(
            choices: [{ message: { content: '{"name":"Test"}' } }],
            usage: { prompt_tokens: 50, completion_tokens: 10 }
          ),
          headers: { "Content-Type" => "application/json" }
        )

      hash_scraper = described_class.new(schema: hash_schema, config: config)
      result = hash_scraper.extract("content")

      expect(result).to be_success
      expect(result.data[:name]).to eq("Test")
    end
  end
end
