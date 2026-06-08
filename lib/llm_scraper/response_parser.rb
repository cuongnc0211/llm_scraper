# frozen_string_literal: true

module LlmScraper
  class ResponseParser
    # @param content [String] raw LLM response
    # @param schema [Schema]
    # @return [Hash]
    # @raise [LlmScraper::ParseError]
    def self.parse(content, schema)
      new(schema).parse(content)
    end

    def initialize(schema)
      @schema = schema
    end

    def parse(content)
      json    = strip_fences(content)
      data    = JSON.parse(json)
      coerced = coerce(data)
      validate_required!(coerced)
      coerced
    rescue JSON::ParserError => e
      raise LlmScraper::ParseError, "Invalid JSON from LLM: #{e.message}\nRaw: #{content}"
    end

    private

    # Strip markdown fences in case LLM ignores the instruction
    def strip_fences(content)
      content
        .gsub(/\A```(?:json)?\s*/i, "")
        .gsub(/\s*```\z/, "")
        .strip
    end

    def coerce(data)
      @schema.fields.each_with_object({}) do |(name, field), result|
        raw          = data[name.to_s]
        result[name] = raw.nil? ? field.default : coerce_value(raw, field)
      end
    end

    def coerce_value(value, field)
      return nil if value.nil?

      case field.type
      when :number  then coerce_number(value)
      when :boolean then coerce_boolean(value)
      when :array   then Array(value)
      else value.to_s
      end
    end

    # Strips currency symbols and thousands separators: "¥150,000" → 150000
    def coerce_number(value)
      return value if value.is_a?(Numeric)

      cleaned = value.to_s.gsub(/[^\d.\-]/, "")
      return nil if cleaned.empty?

      cleaned.include?(".") ? cleaned.to_f : cleaned.to_i
    end

    def coerce_boolean(value)
      return value if value == true || value == false

      %w[true yes 1].include?(value.to_s.downcase)
    end

    def validate_required!(data)
      @schema.fields.each do |name, field|
        next unless field.required
        next unless data[name].nil?

        raise LlmScraper::ParseError, "Required field '#{name}' is missing or null in LLM response"
      end
    end
  end
end
