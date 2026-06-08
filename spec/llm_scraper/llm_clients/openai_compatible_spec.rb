# frozen_string_literal: true

RSpec.describe LlmScraper::LlmClients::OpenaiCompatible do
  let(:config) do
    LlmScraper::Configuration.new.tap do |c|
      c.llm_provider = :openai_compatible
      c.llm_base_url = "https://api.deepseek.com/v1"
      c.llm_api_key  = "test-key"
      c.llm_model    = "deepseek-v4-flash"
      c.llm_timeout  = 30
    end
  end

  let(:client) { described_class.new(config) }

  let(:success_body) do
    JSON.generate(
      choices: [{ message: { content: '{"name":"Gu Jingzhou"}' } }],
      usage: { prompt_tokens: 100, completion_tokens: 20 }
    )
  end

  describe "#complete" do
    it "returns content, tokens, and cost on success" do
      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

      result = client.complete("Extract data")

      expect(result[:content]).to eq('{"name":"Gu Jingzhou"}')
      expect(result[:tokens]).to eq({ input: 100, output: 20 })
      expect(result[:cost_usd]).to be_a(Float)
    end

    it "sends json_object response_format" do
      stub = stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .with(body: hash_including("response_format" => { "type" => "json_object" }))
        .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

      client.complete("Extract data")

      expect(stub).to have_been_requested
    end

    it "raises LlmError on 4xx response" do
      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_return(status: 401, body: "Unauthorized")

      expect { client.complete("Extract data") }
        .to raise_error(LlmScraper::LlmError, /401/)
    end

    it "raises LlmError on network failure" do
      stub_request(:post, "https://api.deepseek.com/v1/chat/completions")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      expect { client.complete("Extract data") }
        .to raise_error(LlmScraper::LlmError, /connection refused/)
    end

    it "preserves base URL path for Gemini-style endpoints" do
      gemini_config = config.dup.tap do |c|
        c.llm_base_url = "https://generativelanguage.googleapis.com/v1beta/openai"
        c.llm_model    = "gemini-2.5-flash"
      end
      gemini_client = described_class.new(gemini_config)

      stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")
        .to_return(status: 200, body: success_body, headers: { "Content-Type" => "application/json" })

      gemini_client.complete("Extract data")

      expect(stub).to have_been_requested
    end
  end
end
