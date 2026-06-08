# frozen_string_literal: true

module LlmScraper
  class PromptBuilder
    # @param schema [Schema]
    # @param content [String]
    # @return [String]
    def self.build(schema, content)
      new(schema).build(content)
    end

    def initialize(schema)
      @schema = schema
    end

    def build(content)
      <<~PROMPT
        Extract the following fields from the content below.
        Return ONLY a valid JSON object. No markdown fences. No explanation.

        Fields:
        #{render_fields}
        Rules:
        - Missing field → null (never omit the key)
        - Return nothing except the JSON object

        Content:
        #{content}
      PROMPT
    end

    private

    def render_fields
      @schema.fields.map { |name, field| render_field(name, field) }.join("\n")
    end

    def render_field(name, field)
      if field.has_instructions?
        render_detailed(name, field)
      else
        render_inline(name, field)
      end
    end

    # Simple fields: single line
    def render_inline(name, field)
      label = build_type_label(field)
      what  = field.what || name.to_s
      "- #{name} (#{label}): #{what}"
    end

    # Fields with how/examples/enum: multiline block
    def render_detailed(name, field)
      label = build_type_label(field)
      lines = ["- #{name} (#{label}):"]
      lines << "    Field: #{field.what}"          if field.what
      lines << "    Instructions: #{field.how}"    if field.how
      lines << "    Examples: #{field.examples.join(", ")}" if field.examples
      lines << "    Allowed values: #{field.enum.join(", ")}" if field.enum
      lines.join("\n")
    end

    def build_type_label(field)
      base = if field.type == :array
               field.items ? "array of #{field.items}" : "array"
             else
               field.type.to_s
             end
      field.required ? "#{base}, required" : base
    end
  end
end
