# frozen_string_literal: true

module DataStruct
  Enum = Struct.new(:allowed_values) do
    def verify!(key, value)
      return if allowed_values.include?(value)

      raise DataStruct::InvalidParameterError,
            "Unexpected enum value `#{value}` for key `#{key}`. Expected one of: #{allowed_values.join(',')}"
    end
  end
end
