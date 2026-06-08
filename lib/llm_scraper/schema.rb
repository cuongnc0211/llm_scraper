# frozen_string_literal: true

module LlmScraper
  class Schema
    attr_reader :fields

    # @param block [Proc] DSL block
    # @return [Schema]
    def self.define(&block)
      schema = new
      schema.instance_eval(&block)
      schema
    end

    # @param hash [Hash] { field_name => { type:, description:, ... } }
    # @return [Schema]
    def self.from_hash(hash)
      schema = new
      hash.each do |name, opts|
        schema.field(name.to_sym, **opts.transform_keys(&:to_sym))
      end
      schema
    end

    def initialize
      @fields = {}
    end

    # @param name [Symbol]
    # @param type [Symbol] :string | :number | :boolean | :array | :object
    # @param options [Hash]
    def field(name, type:, **options)
      @fields[name.to_sym] = Field.new(name: name.to_sym, type: type, **options)
    end

    class Field
      VALID_TYPES = %i[string number boolean array object].freeze

      attr_reader :name, :type, :what, :how, :examples, :enum,
                  :required, :default, :items

      def initialize(name:, type:, description: nil, what: nil, how: nil,
                     examples: nil, enum: nil, required: false,
                     default: nil, items: nil, **_rest)
        @name     = name
        @type     = type.to_sym
        @what     = what || description
        @how      = how
        @examples = examples
        @enum     = enum
        @required = required
        @default  = default
        @items    = items

        validate!
      end

      # True when field has extraction instructions beyond just a label
      def has_instructions?
        !@how.nil? || !@examples.nil? || !@enum.nil?
      end

      private

      def validate!
        return if VALID_TYPES.include?(@type)

        raise LlmScraper::SchemaError, "Field '#{@name}': unsupported type '#{@type}'"
      end
    end
  end
end
