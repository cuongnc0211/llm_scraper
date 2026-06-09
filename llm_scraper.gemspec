# frozen_string_literal: true

require_relative "lib/llm_scraper/version"

Gem::Specification.new do |spec|
  spec.name = "llm_scraper"
  spec.version = LlmScraper::VERSION
  spec.authors = ["cuongnc0211"]
  spec.email = ["cuongnguyenfu@gmail.com"]

  spec.summary = "Extract structured JSON from web pages using LLMs"
  spec.description = "Pipeline: URL → ContentFetcher (Markdown) → LlmClient (JSON). Supports Jina/Firecrawl fetchers and OpenAI-compatible/Anthropic LLM providers."
  spec.homepage = "https://github.com/cuongnc0211/llm_scraper"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday",           ">= 1.10"
  spec.add_dependency "faraday-retry",     ">= 2.0"
  spec.add_dependency "nokogiri",          ">= 1.15"
  spec.add_dependency "reverse_markdown",  ">= 2.0"
  spec.add_dependency "zeitwerk",          ">= 2.6"

  spec.add_development_dependency "rspec",            "~> 3.0"
  spec.add_development_dependency "vcr",              "~> 6.0"
  spec.add_development_dependency "webmock",          "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
