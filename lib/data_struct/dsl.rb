# frozen_string_literal: true

require_relative "boolean"

module DataStruct
  # Declarative class methods for DataStructs
  module DSL
    def define_attributes(field_definitions = {})
      field_definitions.deep_stringify_keys!
      defined_attributes.merge!(field_definitions)
      attr_reader(*field_definitions.keys)

      field_definitions.each do |name, defn|
        next unless defn == DataStruct::Boolean

        method_name = "#{name}?".delete_prefix("is_").delete_prefix("has_")
        define_method(method_name) { public_send(name) }
      end
    end

    def defined_attributes
      @defined_attributes ||= {}
    end

    def convert(src, to:, with:)
      conversions[[src, to]] = with
    end

    def conversions
      @conversions ||=
        (module_parent.respond_to?(:conversions) ? module_parent.conversions : DataStruct::BUILTIN_CONVERSIONS).dup
    end

    def define(name, field_definitions, &block)
      clazz = Class.new(DataStruct::Base, &block)
      clazz.define_attributes(field_definitions)
      # inherit converters from parent
      clazz.conversions.reverse_merge!(conversions)
      # define a constant so it can be referenced by name
      const_set(name, clazz)
      clazz
    end
  end
end
