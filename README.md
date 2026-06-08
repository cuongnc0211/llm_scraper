# LlmScraper

Extract structured JSON from any web page using LLMs — more reliable than CSS selectors, works even when markup changes.

```
URL → ContentFetcher (URL → Markdown) → LlmClient (Markdown → JSON) → Result
```

Two independent layers let you mix any fetcher with any LLM provider.

## Features

- **Schema DSL** — declare fields with `type`, `what`, `how`, `examples`, `enum`, `required`, `default`
- **Multiple fetchers** — Jina AI, Firecrawl, ScrapeGraphAI Markdownify, or local Nokogiri (+ optional Ferrum for SPA)
- **Multiple LLM providers** — any OpenAI-compatible API (DeepSeek, Kimi, GLM, Gemini, OpenRouter…) or Anthropic native
- **Automatic retry** — re-prompts once with stricter instructions on JSON parse failure
- **Cost estimation** — `result.cost_usd` based on token usage
- **Minimal dependencies** — Faraday + Nokogiri + Zeitwerk, no Rails required

## Installation

Add to your Gemfile:

```ruby
gem "llm_scraper"
```

Or install directly:

```bash
gem install llm_scraper
```

## Quick Start

```ruby
require "llm_scraper"

LlmScraper.configure do |c|
  c.llm_provider = :openai_compatible
  c.llm_base_url = "https://api.deepseek.com/v1"
  c.llm_api_key  = ENV["DEEPSEEK_API_KEY"]
  c.llm_model    = "deepseek-v4-flash"
  c.fetcher      = :jina
  c.jina_api_key = ENV["JINA_API_KEY"]   # optional — 200 req/day free without key
end

schema = LlmScraper::Schema.define do
  field :name,  type: :string,  required: true, description: "Full name of the artisan"
  field :price, type: :number,  what: "Current retail price",
                                how: "Return CNY value as a number, strip ¥ symbol"
  field :style, type: :string,  enum: ["yixing", "zhuni", "duanni"]
end

result = LlmScraper::Scraper.new(schema: schema).scrape("https://example.com/teapot")

result.success?      # => true
result.data          # => { name: "Gu Jingzhou", price: 15000, style: "yixing" }
result.tokens_used   # => { input: 4821, output: 87 }
result.cost_usd      # => 0.0009
result.fetcher       # => :jina
result.provider      # => :openai_compatible
result.duration_ms   # => 1842
```

## Schema DSL

```ruby
schema = LlmScraper::Schema.define do
  # Simple field — description is enough
  field :name,      type: :string,  required: true, description: "Full artisan name"
  field :available, type: :boolean, default: true,  description: "In stock status"

  # Complex field — what identifies the field, how tells the LLM how to extract it
  field :price,
        type:     :number,
        what:     "Current retail price (not auction, not historical)",
        how:      "Return CNY as a plain number, strip ¥. If multiple prices, take the lowest",
        examples: [1500, 8000, 25000]

  # Closed-set field — LLM must pick from the list
  field :clay_type,
        type:     :string,
        what:     "Clay type used",
        how:      "Return lowercase English name",
        enum:     ["zisha", "zhuni", "duanni", "hongni"]

  # Array field
  field :techniques, type: :array, items: :string,
        description: "Distinctive crafting techniques"
end
```

### Field options

| Option | Purpose |
|---|---|
| `type` | `:string`, `:number`, `:boolean`, `:array`, `:object` |
| `description` | Alias for `what` — use for simple fields |
| `what` | What this field is (identity, disambiguation) |
| `how` | Extraction instruction (normalization, format, edge cases) |
| `examples` | Few-shot values to improve accuracy |
| `enum` | Closed-set — LLM must pick one of these values |
| `required` | Raises `ParseError` if null after extraction |
| `default` | Fallback value when field is missing |
| `items` | Element type for `type: :array` |

Schema can also be a plain Hash:

```ruby
schema = {
  name:  { type: :string,  required: true, description: "Artisan name" },
  price: { type: :number,  description: "Price in CNY" },
}
```

## Fetchers

### Jina AI (default, recommended)

Clean Markdown via `r.jina.ai` — no JS execution needed, generous free tier.

```ruby
c.fetcher      = :jina
c.jina_api_key = ENV["JINA_API_KEY"]   # optional, ~200 req/day without key
```

### Firecrawl

Higher fidelity, handles JS-heavy pages, 1 credit per page.

```ruby
c.fetcher            = :firecrawl
c.firecrawl_api_key  = ENV["FIRECRAWL_API_KEY"]
```

### ScrapeGraphAI Markdownify

```ruby
c.fetcher               = :markdownify
c.markdownify_api_key   = ENV["MARKDOWNIFY_API_KEY"]
```

### Local (Nokogiri)

No external API — fetches directly and strips boilerplate HTML with Nokogiri.

```ruby
c.fetcher = :local
```

For SPA pages that require JavaScript, add `ferrum` to your Gemfile:

```ruby
gem "ferrum"
```

## LLM Providers

### OpenAI-compatible (DeepSeek, Kimi, GLM, Gemini, OpenRouter…)

```ruby
# DeepSeek V4 Flash — cheap and accurate
c.llm_provider = :openai_compatible
c.llm_base_url = "https://api.deepseek.com/v1"
c.llm_api_key  = ENV["DEEPSEEK_API_KEY"]
c.llm_model    = "deepseek-v4-flash"

# GLM-4.7-Flash — free, good for testing
c.llm_base_url = "https://open.bigmodel.cn/api/paas/v4"
c.llm_api_key  = ENV["GLM_API_KEY"]
c.llm_model    = "glm-4.7-flash"

# Gemini 2.5 Flash
c.llm_base_url = "https://generativelanguage.googleapis.com/v1beta/openai"
c.llm_api_key  = ENV["GEMINI_API_KEY"]
c.llm_model    = "gemini-2.5-flash"

# Kimi K2.5 — long context, auto cache
c.llm_base_url = "https://api.moonshot.ai/v1"
c.llm_api_key  = ENV["KIMI_API_KEY"]
c.llm_model    = "kimi-k2.5"
```

### Anthropic

```ruby
c.llm_provider = :anthropic
c.llm_api_key  = ENV["ANTHROPIC_API_KEY"]
c.llm_model    = "claude-haiku-4-5-20251001"
```

## API

### `Scraper#scrape(url, rescue_errors: false)`

Fetch URL then extract. Raises on error by default; pass `rescue_errors: true` to get a failure `Result` instead.

### `Scraper#extract(content)`

Extract from raw HTML/Markdown — skips the fetch step.

### `Scraper#scrape_batch(urls)`

Scrapes multiple URLs. Never raises — errors are captured in `result.error` per item.

```ruby
results = scraper.scrape_batch(["https://...", "https://..."])
results.each { |r| puts r.data if r.success? }
```

### `Scraper#with_provider(provider)` / `#with_fetcher(fetcher)`

Return a new `Scraper` with a swapped provider or fetcher — original is unchanged.

```ruby
cheap    = scraper.with_provider(:openai_compatible)
accurate = scraper.with_provider(:anthropic)
offline  = scraper.with_fetcher(:local)
```

### `Result`

| Field | Type | Description |
|---|---|---|
| `data` | `Hash` | Extracted fields (symbol keys) |
| `success?` | `Boolean` | |
| `error` | `String\|nil` | Error message on failure |
| `url` | `String\|nil` | Source URL |
| `fetcher` | `Symbol` | Fetcher used |
| `provider` | `Symbol` | LLM provider used |
| `model` | `String` | Model name |
| `tokens_used` | `Hash` | `{ input:, output: }` |
| `cost_usd` | `Float` | Estimated cost |
| `duration_ms` | `Integer` | Total wall time |

## Estimated Cost (1,000 pages/day)

| Combo | Fetcher | LLM/day | Total/day |
|---|---|---|---|
| Jina free + GLM-4.7-Flash | $0 | $0 | **$0** |
| Jina free + DeepSeek V4 Flash | $0 | ~$0.85 | **~$0.85** |
| Local + DeepSeek V4 Flash | $0 | ~$2–4 | **~$2–4** |
| Jina free + Claude Haiku | $0 | ~$3–5 | **~$3–5** |

> Local fetcher produces ~4× more tokens than Jina Markdown.

## Development

```bash
git clone https://github.com/cuongnc0211/llm_scraper
cd llm_scraper
bundle install

cp .env.example .env
# Add your API keys to .env

bundle exec rspec        # run tests
bin/console              # interactive console with dotenv loaded
```

## Contributing

Bug reports and pull requests are welcome at https://github.com/cuongnc0211/llm_scraper.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
