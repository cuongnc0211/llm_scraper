# frozen_string_literal: true

require "zeitwerk"
require "faraday"
require "faraday/retry"
require "nokogiri"
require "reverse_markdown"
require "json"

loader = Zeitwerk::Loader.for_gem
loader.setup

module LlmScraper
  class Error              < StandardError; end
  class FetchError         < Error; end
  class LlmError           < Error; end
  class ParseError         < Error; end
  class SchemaError        < Error; end
  class ConfigurationError < Error; end

  def self.configure
    yield configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.reset_configuration!
    @configuration = Configuration.new
  end
end
