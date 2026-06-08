# frozen_string_literal: true

RSpec.describe LlmScraper::PromptBuilder do
  let(:content) { "Some page content" }

  def schema(&block)
    LlmScraper::Schema.define(&block)
  end

  describe ".build" do
    it "renders simple field inline" do
      s = schema { field :name, type: :string, description: "Artist name" }
      prompt = described_class.build(s, content)
      expect(prompt).to include("- name (string): Artist name")
    end

    it "marks required fields" do
      s = schema { field :name, type: :string, required: true, description: "Artist name" }
      prompt = described_class.build(s, content)
      expect(prompt).to include("(string, required)")
    end

    it "renders detailed block when how is present" do
      s = schema do
        field :price, type: :number,
              what: "Retail price", how: "CNY numeric only"
      end
      prompt = described_class.build(s, content)
      expect(prompt).to include("Field: Retail price")
      expect(prompt).to include("Instructions: CNY numeric only")
    end

    it "renders examples line" do
      s = schema { field :price, type: :number, what: "Price", examples: [1500, 8000] }
      prompt = described_class.build(s, content)
      expect(prompt).to include("Examples: 1500, 8000")
    end

    it "renders allowed values line for enum" do
      s = schema do
        field :clay, type: :string, what: "Clay type",
              enum: ["zisha", "zhuni"]
      end
      prompt = described_class.build(s, content)
      expect(prompt).to include("Allowed values: zisha, zhuni")
    end

    it "renders array type with items" do
      s = schema { field :tags, type: :array, items: :string, description: "Tags" }
      prompt = described_class.build(s, content)
      expect(prompt).to include("(array of string)")
    end

    it "includes content at the end" do
      s = schema { field :name, type: :string, description: "Name" }
      prompt = described_class.build(s, content)
      expect(prompt).to end_with("#{content}\n")
    end

    it "includes the rules section" do
      s = schema { field :name, type: :string, description: "Name" }
      prompt = described_class.build(s, content)
      expect(prompt).to include("Missing field → null")
    end
  end
end
