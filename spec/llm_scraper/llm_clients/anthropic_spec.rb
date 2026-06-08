# frozen_string_literal: true

RSpec.describe LlmScraper::LlmClients::Anthropic do
  let(:config) do
    LlmScraper::Configuration.new.tap do |c|
      c.llm_provider = :anthropic
      c.llm_api_key  = "test-key"
      c.llm_model    = "claude-haiku-4-5-20251001"
      c.llm_timeout  = 30
    end
  end

  let(:client) { described_class.new(config) }

  let(:success_body) do
    JSON.generate(
      content: [{ text: '{"name":"Gu Jingzhou"}' }],
      usage: { input_tokens: 120, output_tokens: 25 }
    )
  end

  describe "#complete" do
    it "returns content, tokens, and cost on success" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

      result = client.complete("Extract data")

      expect(result[:content]).to eq('{"name":"Gu Jingzhou"}')
      expect(result[:tokens]).to eq({ input: 120, output: 25 })
      expect(result[:cost_usd]).to be_a(Float)
    end

    it "sends correct Anthropic headers" do
      stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
        .with(headers: { "x-api-key" => "test-key", "anthropic-version" => "2023-06-01" })
        .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

      client.complete("Extract data")

      expect(stub).to have_been_requested
    end

    it "does not send response_format (Anthropic unsupported)" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

      client.complete("Extract data")

      expect(WebMock).to have_requested(:post, "https://api.anthropic.com/v1/messages")
        .with { |req| !JSON.parse(req.body).key?("response_format") }
    end

    it "raises LlmError on 4xx response" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_return(status: 401, body: "Unauthorized")

      expect { client.complete("Extract data") }
        .to raise_error(LlmScraper::LlmError, /401/)
    end

    it "raises LlmError on network failure" do
      stub_request(:post, "https://api.anthropic.com/v1/messages")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { client.complete("Extract data") }
        .to raise_error(LlmScraper::LlmError, /connection refused/)
    end
  end
end
