# frozen_string_literal: true

module LlmScraper
  class Scraper
    # @param schema [Schema, Hash]
    # @param config [Configuration]
    def initialize(schema:, config: LlmScraper.configuration)
      @schema = normalize_schema(schema)
      @config = config
    end

    # @param url [String]
    # @param rescue_errors [Boolean] return error Result instead of raising
    # @param spa [Boolean] use headless Chrome for JS-rendered pages (local fetcher only)
    # @return [Result]
    # @raise [LlmScraper::Error] when rescue_errors is false
    def scrape(url, rescue_errors: false, spa: false)
      start = monotonic_now
      result = run_pipeline(url: url, spa: spa)
      attach_timing(result, start)
    rescue LlmScraper::Error => e
      raise unless rescue_errors

      Result.new(success: false, error: e.message, url: url,
                 fetcher: @config.fetcher, provider: @config.llm_provider,
                 model: @config.llm_model)
    end

    # Extract from raw content — skips fetching step
    # @param content [String]
    # @return [Result]
    def extract(content)
      start = monotonic_now
      attach_timing(run_llm_pipeline(content: content), start)
    end

    # @param urls [Array<String>]
    # @param spa [Boolean] use headless Chrome for JS-rendered pages (local fetcher only)
    # @return [Array<Result>] never raises — errors captured in result.error
    def scrape_batch(urls, spa: false)
      urls.map { |url| scrape(url, rescue_errors: true, spa: spa) }
    end

    # @param provider [Symbol] :openai_compatible | :anthropic
    # @return [Scraper] new instance with swapped LLM provider
    def with_provider(provider)
      self.class.new(schema: @schema, config: clone_config(llm_provider: provider))
    end

    # @param fetcher [Symbol] :jina | :firecrawl | :markdownify | :local
    # @return [Scraper] new instance with swapped fetcher
    def with_fetcher(fetcher)
      self.class.new(schema: @schema, config: clone_config(fetcher: fetcher))
    end

    private

    def run_pipeline(url:, spa: false)
      fetcher = build_fetcher
      content = @config.fetcher == :local ? fetcher.fetch(url, spa: spa) : fetcher.fetch(url)
      result  = run_llm_pipeline(content: content)
      result.url     = url
      result.fetcher = @config.fetcher
      result
    end

    def run_llm_pipeline(content:)
      client     = build_llm_client
      prompt     = PromptBuilder.build(@schema, content)
      llm_result = client.complete(prompt)
      data       = parse_with_retry(llm_result[:content], client, prompt)

      Result.new(
        data:        data,
        success:     true,
        provider:    @config.llm_provider,
        model:       @config.llm_model,
        tokens_used: llm_result[:tokens],
        cost_usd:    llm_result[:cost_usd]
      )
    end

    # Retry once with a stricter prompt on JSON parse failure
    def parse_with_retry(content, client, original_prompt)
      ResponseParser.parse(content, @schema)
    rescue LlmScraper::ParseError
      retry_prompt = original_prompt +
        "\n\nCRITICAL: Return ONLY the JSON object. Example output: {\"field\": \"value\"}"
      llm_result = client.complete(retry_prompt)
      ResponseParser.parse(llm_result[:content], @schema)
    end

    def build_fetcher
      case @config.fetcher
      when :jina        then ContentFetchers::Jina.new(@config)
      when :firecrawl   then ContentFetchers::Firecrawl.new(@config)
      when :markdownify then ContentFetchers::Markdownify.new(@config)
      when :local       then ContentFetchers::Local.new(@config)
      else raise ConfigurationError, "Unknown fetcher: #{@config.fetcher.inspect}"
      end
    end

    def build_llm_client
      case @config.llm_provider
      when :openai_compatible then LlmClients::OpenaiCompatible.new(@config)
      when :anthropic         then LlmClients::Anthropic.new(@config)
      else raise ConfigurationError, "Unknown LLM provider: #{@config.llm_provider.inspect}"
      end
    end

    def normalize_schema(schema)
      case schema
      when Schema then schema
      when Hash   then Schema.from_hash(schema)
      else raise SchemaError, "schema must be a Hash or LlmScraper::Schema instance"
      end
    end

    def clone_config(**overrides)
      new_config = @config.dup
      overrides.each { |key, val| new_config.public_send(:"#{key}=", val) }
      new_config
    end

    def attach_timing(result, start)
      result.duration_ms = ((monotonic_now - start) * 1000).round
      result
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
