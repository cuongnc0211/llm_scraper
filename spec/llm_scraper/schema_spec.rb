# frozen_string_literal: true

RSpec.describe LlmScraper::Schema do
  describe ".define" do
    it "builds schema from DSL block" do
      schema = described_class.define do
        field :name, type: :string, required: true, description: "Artist name"
        field :price, type: :number, what: "Retail price", how: "CNY numeric only"
      end

      expect(schema.fields.keys).to eq([:name, :price])
    end

    it "aliases description to what" do
      schema = described_class.define do
        field :name, type: :string, description: "Artist name"
      end

      expect(schema.fields[:name].what).to eq("Artist name")
    end
  end

  describe ".from_hash" do
    it "builds schema from hash" do
      schema = described_class.from_hash(
        name:  { type: :string, required: true },
        price: { type: :number }
      )

      expect(schema.fields[:name].required).to be true
      expect(schema.fields[:price].type).to eq(:number)
    end
  end

  describe LlmScraper::Schema::Field do
    it "raises SchemaError for unsupported type" do
      expect {
        described_class.new(name: :foo, type: :invalid)
      }.to raise_error(LlmScraper::SchemaError, /unsupported type/)
    end

    it "detects instructions when how is present" do
      field = described_class.new(name: :price, type: :number, how: "CNY only")
      expect(field.has_instructions?).to be true
    end

    it "detects instructions when enum is present" do
      field = described_class.new(name: :clay, type: :string, enum: ["zisha"])
      expect(field.has_instructions?).to be true
    end

    it "detects instructions when examples present" do
      field = described_class.new(name: :price, type: :number, examples: [1500])
      expect(field.has_instructions?).to be true
    end

    it "has no instructions for plain description-only field" do
      field = described_class.new(name: :name, type: :string, description: "Name")
      expect(field.has_instructions?).to be false
    end
  end
end
