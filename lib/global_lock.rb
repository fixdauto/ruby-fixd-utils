# frozen_string_literal: true

require "rails"
require "redis-semaphore"

# There are situations where concurrent access to the same data can cause problems. Regular
# concurrency primitves aren't really in Ruby, as even when Ruby is using multiple threads
# (which is the case with webservers like Puma but not the way ruby was designed at the start),
# only one thread can be executing Ruby code at the same time. This leads to typically running
# Ruby with concurrent processes (again, like with Puma). Between webserver threads and processes,
# and background threads/processes (e.g. Sidekiq), we need a way to be able to limit concurrent
# access to a critical path globally across all running processes in the application.
#
# In environments where we have Redis configured, we can use it as a global location to track
# locks (using https://github.com/dv/redis-semaphore). In environments where redis isn't available
# (e.g. test), we assume the env is single-process and we use a traditional Ruby primitive.
#
# There are some complicated performance and stability considerations when using this, so it's best
# to use sparringly. Before use, consider if there's a way to change the problem so that a global
# lock isn't neccessary. Can the function call be made idempotent?
#
#
# Here's some test mechanisms:
#   Redis-backed - paste twice in separate consoles:
#     Benchmark.measure do
#       GlobalLock.aquire('foo2') do
#         sleep 10.seconds
#         puts "ok"
#       end
#     end.real
#
#     Benchmark.measure do
#       GlobalLock.aquire('foo2', wait_max: 1.second) do
#         sleep 10.seconds
#         puts "ok"
#       end
#     end.real
#
#     # run in 2 consoles, and then stop one of them with Ctrl-C
#     Benchmark.measure do
#       GlobalLock.aquire('foo3', expires: 30.seconds) do
#         sleep 10.seconds
#         puts "ok"
#       end
#     end.real
#
#   Single-process: run in one console
#     2.times.map do |i|
#       Thread.new do
#         t = Benchmark.measure do
#           GlobalLock::SingleProcessLock.aquire('foo2', wait_max: nil) do
#             sleep 10.seconds
#             puts "ok"
#           end
#         end
#         puts "#{i}: #{t.real}"
#       end
#     end.each(&:join)
#
#     2.times.map do |i|
#       Thread.new do
#         t = Benchmark.measure do
#           GlobalLock::SingleProcessLock.aquire('foo2', wait_max: 1.second) do
#             sleep 10.seconds
#             puts "ok"
#           end
#         end
#         puts "#{i}: #{t.real}"
#       end
#     end.each(&:join)
#
module GlobalLock
  module_function

  class LockTimeoutError < StandardError; end

  # Create a named lock by `key`. If the process is terminated early, allow the lock to expire
  # automatically after `expires`. If `wait_max` is supplied, this will not block for longer than
  # that waiting for the lock to be avialable, and throw LockTimeoutError instead. If not supplied,
  # will block as long as required.
  def aquire(*args, **kwargs, &block)
    default_implementation.aquire(*args, **kwargs, &block)
  end

  def default_implementation
    return SingleProcessLock if Rails.env.test?
    return SingleProcessLock if Rails.env.development? && ENV.fetch("USE_REDIS", "false") != "true"

    RedisLock.new(Rails.application.config.redis_config.dup)
  end

  # Redis-backed implementation of GlobalLock.
  #
  # Note: we use the redis config here instead of a redis instance itself, due to the
  # concerns noted in the project: https://github.com/dv/redis-semaphore/issues/18
  #
  # Note: this is really hard to write unit tests for, given tests don't have redis
  # and are single process. The only way I know to test is open 2 rails consoles and
  # play with it.
  class RedisLock
    def initialize(redis_config)
      @redis_config = redis_config
    end

    def aquire(key, expires: 5.minutes, wait_max: nil, &block)
      opts = @redis_config.merge(stale_client_timeout: expires, expiration: expires * 2)
      semaphore = Redis::Semaphore.new(key, opts)
      return semaphore.lock(&block) if wait_max.blank?

      # rubocop:disable Style/GuardClause
      # I think a guard clause here would make this logic harder to follow
      if semaphore.lock(wait_max.to_f)
        begin
          block.call
        ensure
          semaphore.unlock
        end
      else
        raise LockTimeoutError, "waited #{wait_max} for a lock but it did not become available"
      end
      # rubocop:enable Style/GuardClause
    end
  end

  # Redis-free implementation that works on a single process
  module SingleProcessLock
    module_function

    def aquire(key, opts = {}, &block)
      @locks ||= {}
      @locks[key] ||= Mutex.new
      wait_max = opts[:wait_max]

      return @locks[key].synchronize(&block) if wait_max.blank?

      # this could easily wait longer than wait_max, but it will wait *at least* that long.
      start = Time.zone.now
      while Time.zone.now < start + wait_max
        if @locks[key].try_lock
          begin
            return block.call
          ensure
            @locks[key].unlock
          end
        else
          sleep(0.1)
        end
      end
      raise LockTimeoutError, "waited #{wait_max} for a lock but it did not become available"
    end
  end
end
