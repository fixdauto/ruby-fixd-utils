# frozen_string_literal: true

require 'active_model'

require_relative 'boolean'
require_relative 'dsl'
require_relative 'enum'

module DataStruct
  # The base class to inherit from to create a DataStruct
  class Base
    extend DataStruct::DSL
    include ActiveModel::Model

    def initialize(attrs)
      @original_attributes = attrs.to_hash.deep_stringify_keys
      super(_verify!(_convert(_filter(@original_attributes))))
    end

    def to_hash
      @original_attributes
    end

    def ==(other)
      return false if other.nil?
      return false unless other.instance_of?(self.class)

      to_hash == other.to_hash
    end

    def copy(new_attributes = {})
      self.class.new(@original_attributes.merge(new_attributes.to_hash.deep_stringify_keys))
    end

    private

    def _assign_attribute(k, v) # rubocop:disable Naming/MethodParameterName
      # override ActiveModel implementation to not use setters
      instance_variable_set("@#{k}", v)
    end

    # here we use _ prefix to avoid naming conflicts with data fields

    def _filter(attrs)
      attrs.slice(*attrs.keys.select { |k| self.class.defined_attributes.key?(k) })
    end

    def _convert(attrs)
      attrs.each_with_object({}) do |(k, v), p|
        p[k] = _convert_value(self.class.defined_attributes[k], self.class, k, v)
      end
    end

    def _convert_value(defn, parent_defn, key, value)
      return value if value.nil?
      return _convert_array(defn, parent_defn, key, value) if defn.is_a?(Array)
      return _convert_nested_object(defn, value) if _nested_object?(defn)

      conversion = self.class.conversions[[value.class, defn]]
      return value unless conversion
      return value.send(conversion) if conversion.is_a?(Symbol) || conversion.is_a?(String)

      conversion.call(value)
    end

    def _convert_nested_object(defn, value)
      return value if value.is_a?(defn)

      defn.new(value)
    end

    def _convert_array(defn, parent_defn, key, value)
      inner_defn = defn.first
      unless value.is_a?(Array)
        raise DataStruct::InvalidParameterError,
              "Expected `#{key}` to be an array of #{inner_defn} but was `#{value}` (#{value.class})"
      end
      value.each_with_index.map { |v, i| _convert_value(inner_defn, parent_defn, "#{key}[#{i}]", v) }
    end

    def _nested_object?(defn)
      defn.respond_to?(:ancestors) && defn.ancestors.include?(DataStruct::Base)
    end

    def _verify!(attrs)
      attrs.each do |k, v|
        defn = self.class.defined_attributes[k.to_s]
        _verify_value!(defn, k, v)
      end
      attrs
    end

    def _verify_value!(defn, key, value)
      return if value.nil?

      if defn.is_a?(Array)
        inner_defn = defn.first
        value.each_with_index { |v, i| _verify_value!(inner_defn, "#{key}[#{i}]", v) }
      elsif defn.is_a?(DataStruct::Enum) then defn.verify!(key, value)
      elsif defn == DataStruct::Boolean then DataStruct::Boolean.verify!(key, value)
      elsif defn != value.class
        raise DataStruct::InvalidParameterError,
              "Expected `#{key}` to be a #{defn} but was `#{value}` (#{value.class}) in #{self.class.name}"
      end
    end
  end
end
