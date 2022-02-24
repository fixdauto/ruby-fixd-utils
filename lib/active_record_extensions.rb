# frozen_string_literal: true

require "active_record"
require "pg/exceptions"

# Database-related utility functions
module ActiveRecordExtensions
  module_function

  # some database operations are not atomic.
  # for example: find a record, and if it doesn't exist, create it.
  # this can create race conditions. Good solutions are hard, but
  # an easy one is to just retry the operation since you know now
  # that the record exists
  def retry_on_conflict(max_attempts: 3, &block)
    attempts = 0
    begin
      block.call
    rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
      # avoid infinite loops, which can happen if there's a bug in the code
      attempts += 1
      retry if attempts < max_attempts
    end
  end
end
