# frozen_string_literal: true

require "active_record"
require "pg/exceptions"
require "after_commit_everywhere"

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

  # Sometimes you need to ensure a database change happens
  # even if the current database change is rolled back.
  # For example, if you go to charge a card and the charge
  # fails, you might want to roll back the order but save the
  # declined transaction to the database. This will run the block
  # after either a commit or a rollback.
  def execute_outside_transaction(&block)
    if AfterCommitEverywhere.in_transaction?
      AfterCommitEverywhere.after_commit(&block)
      AfterCommitEverywhere.after_rollback(&block)
    else
      block.call
    end
  end
end
