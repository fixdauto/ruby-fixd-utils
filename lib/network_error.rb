# frozen_string_literal: true

require "active_support/concern"

# This is a wrapper for lots of different StandardErrors that
# are the result of network connectivity problems. Note: this
# is not the same as API errors, where we got a response from
# upstream but it was an error response. This is specifically
# for errors during transmission of a request.
class NetworkError < StandardError
  attr_reader :cause

  def initialize(cause, message: nil)
    super(message || cause.message)
    @cause = cause
  end

  DEFAULT_ERROR_CLASS_NAMES = [
    # net/http
    # httparty just wraps net/http so it doesn't have special error classes
    "Net::OpenTimeout",
    "Net::ReadTimeout",
    # net/smtp
    "Net::SMTPServerBusy",
    # http [https://github.com/httprb]
    "HTTP::TimeoutError",
    "HTTP::ConnectionError",
    # excon [https://github.com/excon/excon]
    "Excon::Error::Socket",
    "Excon::Error::Timeout",
    "Excon::Error::BadGateway",
    "Excon::Error::ServiceUnavailable",
    "Excon::Error::GatewayTimeout",
    # ssl
    "OpenSSL::SSL::SSLError",
    # low-level OS errors
    "EOFError",
    "SocketError",
    "Errno::EPIPE",
    "Errno::ECONNRESET",
    "Errno::EHOSTUNREACH"
  ].freeze

  class << self
    # is the given exception a network exception?
    def caused_by?(exception, additional_error_classes = [])
      matches_any?(exception, DEFAULT_ERROR_CLASS_NAMES + additional_error_classes.map(&:name))
    end

    def wrap(exception, additional_error_classes = [])
      return exception if exception.is_a?(NetworkError)
      return exception unless caused_by?(exception, additional_error_classes)

      new(exception)
    end

    # Looks at an HTTParty response, and if it's a gateway-related
    # server error raises a NetworkError
    def raise_if_gateway_error!(res)
      raise NetworkError.new(nil, message: "Bad Gateway") if res.code == 501
      raise NetworkError.new(nil, message: "Service Unavailable") if res.code == 503
      raise NetworkError.new(nil, message: "Gateway Timeout") if res.code == 504

      res
    end

    # use this block to cause any network errors raised to
    # become wrapped in NetworkError
    def handle(additional_error_classes = [])
      yield
    rescue StandardError => e
      raise wrap(e, additional_error_classes)
    end

    private

    def matches_any?(error, expected_names)
      return true if class_matches_any?(error.class, expected_names)
      return matches_any?(error.cause, expected_names) if error.cause

      false
    end

    def class_matches_any?(error_class, expected_names)
      return true if expected_names.include?(error_class.name)
      return false unless error_class.superclass

      class_matches_any?(error_class.superclass, expected_names)
    end
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
