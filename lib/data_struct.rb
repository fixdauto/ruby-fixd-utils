# frozen_string_literal: true

require "active_support"
require "active_support/time"

require_relative "data_struct/base"
require_relative "data_struct/boolean"

# Define data classes with basic type validation and conversion.
# Kinda like `Struct.new` but easier to use. Useful for external APIs.
# DataStructs are immutable, effectively wrappers for the provided
# hash data.
# Ignores hash keys which are not defined as attributes. Missing attributes
# are treated as `nil`. Any attribute can be `nil` (all attributes are optional).
# Raises `DataStruct::InvalidParameterError` for type discrepancies.
#
# Here's a basic example:
# ```ruby
# class Foo < DataStruct::Base
#   define_attributes id: Integer,
#     name: String,
#     admin: DataStruct::Boolean, # special case, since Ruby doesn't have a boolean class
#     tags: [String] # primitive arrays

#   define_attributes  score: Float, # you can call define-attributes multiple times
#     registered_at: ActiveSupport::TimeWithZone,
#     next_bill_on: Date, # date and time type conversions
#     state: DataStruct::Enum.new(['pending', 'active', 'expired']) # enums
#     address: define('Address', # nested in-line objects, defines a Foo::Address class
#       street: String,
#       city: String,
#       state: String,
#       zip: String
#     )
#   class Transaction < DataStruct::Base
#     define_attributes id: Integer, amount: Money # conversions can be inherited from containing classes
#   end

#   define_attributes transactions: [Transaction] # nested object arrays, also works in-line

#   # Basic conversions like dates and times are automatically supported.
#   # You can define additional conversions with this constant, mapping
#   # from and to types to a lambda:
#   convert Float, to: Money, with: lambda { |v| v.to_money('USD') }

#   def priority? # custom methods
#     tags.include?('priority')
#   end
# end
# foo = Foo.new(json_representation)
# foo.transactions[0].money
# foo.admin?
# foo.to_hash == json_representation
# Foo.new(json_representation) == foo
# new_foo = foo.copy(is_admin: false)
# ```
#
# See the spec for detailed usage.
module DataStruct
  class InvalidParameterError < StandardError; end

  BUILTIN_CONVERSIONS = {
    [String, Integer] => :to_i,
    [String, Float] => :to_f,
    [String, DataStruct::Boolean] => :to_b,
    [Integer, DataStruct::Boolean] => :to_b,
    [Symbol, String] => :to_s,
    [String, Date] => ->(v) { Date.parse(v) },
    [String, ActiveSupport::TimeWithZone] => ->(v) { Time.zone.parse(v) }
  }.freeze
end
