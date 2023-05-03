# frozen_string_literal: true

require 'active_support'
require 'active_support/time'

# Declare getter and setter methods for `ActiveSupport::Duration` objects
# backed by a column containing the value in seconds. Works with duration
# objects and ISO 8601 strings.
# Example:
# ```ruby
# class Foo < ActiveModel::Model
#   include DurationAttributes
#   attr_accessor :trial_period_seconds
#   duration_attribute :trial_period, unit: :seconds
# end
# foo = Foo.new(trial_period_seconds: 60)
# foo.trial_period # 1.minute
# foo.trial_period = 1.year
# foo.trial_period # 1.year
# foo.trial_period_seconds # 31556952
# foo.trial_period = 'P3M'
# foo.trial_period # 3.months
# foo.trial_period_seconds # 7889238
# ```
#
# It also supports `unit` being a reference to a method:
# ```ruby
# class Foo < ActiveModel::Model
#   include DurationAttributes
#   attr_accessor :trial_period_unit
#   attr_accessor :trial_period_value
#   dynamic_duration_attribute :trial_period
# end
module DurationAttributes
  extend ActiveSupport::Concern

  UNITS = %w[
    minutes
    years
    days
    seconds
    weeks
    months
    hours
  ].freeze

  # rubocop:disable Metrics/BlockLength,Metrics/MethodLength
  class_methods do
    def dynamic_duration_attribute(name, unit_column: "#{name}_unit", value_column: "#{name}_value")
      define_method(name) do
        raw_value = public_send(value_column)
        unit = public_send(unit_column)
        return nil unless raw_value
        raise ArgumentError, "Invalid unit: #{unit}" unless UNITS.include?(unit.to_s)

        ActiveSupport::Duration.send(unit, raw_value)
      end

      define_method("#{name}=") do |duration|
        if duration.nil?
          public_send("#{value_column}=", nil)
          public_send("#{unit_column}=", nil)
          return
        end

        duration = ActiveSupport::Duration.parse(duration) if duration.is_a?(String)
        if duration.parts.size != 1
          raise ArgumentError,
                "Duration attribute `#{name}` can not have more than one unit, given `#{duration.inspect}`"
        end
        unit, value = duration.parts.first
        public_send("#{value_column}=", value)
        public_send("#{unit_column}=", unit.to_s)
      end
    end

    def duration_attribute(name, unit: :seconds, column_name: "#{name}_#{unit}", use_build: unit == :seconds)
      base = ActiveSupport::Duration.send(unit, 1)

      define_method(name) do
        raw_value = public_send(column_name)
        return nil unless raw_value

        if use_build
          ActiveSupport::Duration.build(raw_value * base.to_i)
        else
          ActiveSupport::Duration.send(unit, raw_value)
        end
      end

      define_method("#{name}=") do |duration|
        return public_send("#{column_name}=", nil) if duration.nil?

        duration = ActiveSupport::Duration.parse(duration) if duration.is_a?(String)
        public_send("#{column_name}=", duration / base)
      end
    end
  end
  # rubocop:enable Metrics/BlockLength,Metrics/MethodLength
end
