# frozen_string_literal: true

require_relative 'boolean'

module DataStruct
  # Declarative class methods for DataStructs
  module DSL
    def define_attributes(field_definitions = {})
      field_definitions.deep_stringify_keys!
      defined_attributes.merge!(field_definitions)
      attr_reader(*field_definitions.keys)

      field_definitions.each do |name, defn|
        next unless defn == DataStruct::Boolean

        method_name = "#{name}?".delete_prefix('is_').delete_prefix('has_')
        define_method(method_name) { public_send(name) }
      end
    end

    def defined_attributes
      @defined_attributes ||= {}
    end

    def convert(src, to:, with:)
      conversions[[src, to]] = with
    end

    def permit(params)
      explicit_permits.merge!(params.deep_stringify_keys)
    end

    def explicit_permits
      @explicit_permits ||= {}
    end

    def conversions
      @conversions ||= begin
        conversions = DataStruct::BUILTIN_CONVERSIONS.dup
        conversions.merge!(module_parent.conversions.dup) if module_parent.respond_to?(:conversions)
        conversions.merge!(superclass.conversions.dup) if superclass.respond_to?(:conversions)
        conversions
      end
    end

    def define(name, field_definitions, &)
      clazz = Class.new(DataStruct::Base, &)
      clazz.define_attributes(field_definitions)
      # inherit converters from parent
      clazz.conversions.reverse_merge!(conversions)
      # define a constant so it can be referenced by name
      const_set(name, clazz)
      clazz
    end

    # return a structure of keys that can be passed to
    # ActionController::Parameters#permit to permit all defined parameters.
    def param_keys(clazz = self)
      clazz.defined_attributes.map do |name, defn|
        if explicit_permits[name]
          { name => explicit_permits[name] }
        elsif defn.is_a?(Array)
          if defn[0].respond_to?(:defined_attributes)
            { name => param_keys(defn[0]) }
          else
            { name => [] }
          end
        elsif defn.respond_to?(:defined_attributes)
          { name => param_keys(defn) }
        else
          name
        end
      end
    end
  end
end
