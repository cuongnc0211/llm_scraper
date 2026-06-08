# frozen_string_literal: true

RSpec.describe LlmScraper::ResponseParser do
  def schema(&block)
    LlmScraper::Schema.define(&block)
  end

  describe ".parse" do
    it "parses valid JSON" do
      s = schema { field :name, type: :string, description: "Name" }
      result = described_class.parse('{"name": "Gu Jingzhou"}', s)
      expect(result[:name]).to eq("Gu Jingzhou")
    end

    it "strips markdown fences" do
      s = schema { field :name, type: :string, description: "Name" }
      result = described_class.parse("```json\n{\"name\": \"Test\"}\n```", s)
      expect(result[:name]).to eq("Test")
    end

    it "coerces currency string to number" do
      s = schema { field :price, type: :number, description: "Price" }
      result = described_class.parse('{"price": "¥85,000"}', s)
      expect(result[:price]).to eq(85_000)
    end

    it "passes through numeric values unchanged" do
      s = schema { field :price, type: :number, description: "Price" }
      result = described_class.parse('{"price": 85000}', s)
      expect(result[:price]).to eq(85_000)
    end

    it "coerces boolean strings" do
      s = schema { field :available, type: :boolean, description: "Available" }
      result = described_class.parse('{"available": "yes"}', s)
      expect(result[:available]).to be true
    end

    it "returns false for non-truthy boolean strings" do
      s = schema { field :available, type: :boolean, description: "Available" }
      result = described_class.parse('{"available": "no"}', s)
      expect(result[:available]).to be false
    end

    it "uses field default when value is null" do
      s = schema { field :available, type: :boolean, default: true, description: "Available" }
      result = described_class.parse('{"available": null}', s)
      expect(result[:available]).to be true
    end

    it "sets missing field to nil when no default" do
      s = schema { field :phone, type: :string, description: "Phone" }
      result = described_class.parse("{}", s)
      expect(result[:phone]).to be_nil
    end

    it "raises ParseError on invalid JSON" do
      s = schema { field :name, type: :string, description: "Name" }
      expect { described_class.parse("not json", s) }
        .to raise_error(LlmScraper::ParseError, /Invalid JSON/)
    end

    it "raises ParseError when required field is null" do
      s = schema { field :name, type: :string, required: true, description: "Name" }
      expect { described_class.parse('{"name": null}', s) }
        .to raise_error(LlmScraper::ParseError, /Required field 'name'/)
    end

    it "wraps array values" do
      s = schema { field :tags, type: :array, items: :string, description: "Tags" }
      result = described_class.parse('{"tags": ["a", "b"]}', s)
      expect(result[:tags]).to eq(["a", "b"])
    end
  end
end
