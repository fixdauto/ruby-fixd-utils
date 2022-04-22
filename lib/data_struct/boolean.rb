# frozen_string_literal: true

module DataStruct
  # Special type indicator for booleans, as Ruby doesn't have a type
  class Boolean
    def self.verify!(key, value)
      return if [true, false].include?(value)

      raise DataStruct::InvalidParameterError,
            "Expected `#{key}` to be a Boolean but was `#{value}` (#{value.class})"
    end
  end
end
