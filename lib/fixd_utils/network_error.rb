# frozen_string_literal: true

require 'net/http'
require 'net/smtp'
require 'active_support/concern'

# This is a wrapper for lots of different StandardErrors that
# are the result of network connectivity problems. Note: this
# is not the same as API errors, where we got a response from
# upstream but it was an error response. This is specifically
# for errors during transmission of a request.
module FixdUtils
  class NetworkError < StandardError
    attr_reader :cause

    def initialize(cause, message: nil)
      super(message || cause.message)
      @cause = cause
    end

    ERROR_CLASSES = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Net::SMTPServerBusy,
      OpenSSL::SSL::SSLError,
      EOFError,
      SocketError,
      Errno::EPIPE,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH
    ].freeze

    # is the given exception a network exception?
    def self.caused_by?(exception, additional_error_classes = [])
      (ERROR_CLASSES + additional_error_classes).any? { |c| exception.is_a?(c) }
    end

    def self.wrap(exception, additional_error_classes = [])
      return exception if exception.is_a?(NetworkError)
      return exception unless caused_by?(exception, additional_error_classes)

      new(exception)
    end

    # Looks at an HTTParty response, and if it's a gateway-related
    # server error raises a NetworkError
    def self.raise_if_gateway_error!(res)
      raise NetworkError.new(nil, message: 'Bad Gateway') if res.code == 501
      raise NetworkError.new(nil, message: 'Service Unavailable') if res.code == 503
      raise NetworkError.new(nil, message: 'Gateway Timeout') if res.code == 504

      res
    end

    # use this block to cause any network errors raised to
    # become wrapped in NetworkError
    def self.handle(additional_error_classes = [])
      yield
    rescue StandardError => e
      raise wrap(e, additional_error_classes)
    end

    # Include this to get a class method to automatically wrap
    # individual methods in NetworkError.handle
    module Wrap
      extend ActiveSupport::Concern

      class_methods do
        def handle_network_errors(*methods)
          handler = Module.new do
            methods.each do |method|
              define_method(method) do |*args|
                NetworkError.handle do
                  super(*args)
                end
              end
            end
          end
          prepend(handler)
        end
      end
    end
  end
end
