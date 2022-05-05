# frozen_string_literal: true

require "active_support"
require "active_support/time"

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
module DurationAttributes
  extend ActiveSupport::Concern

  class_methods do
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
end
