# frozen_string_literal: true

require 'spec_helper'

RSpec.describe FixdUtils::NetworkError do
  it 'should know if an error is a network error' do
    expect(FixdUtils::NetworkError.caused_by?(Net::OpenTimeout.new(''))).to eq true
    expect(FixdUtils::NetworkError.caused_by?(OpenSSL::SSL::SSLError.new(''))).to eq true
    expect(FixdUtils::NetworkError.caused_by?(StandardError.new(''))).to eq false
    expect(FixdUtils::NetworkError.caused_by?(ArgumentError.new(''))).to eq false
  end

  it 'should allow handling of network errors by wrapping them' do
    expect do
      FixdUtils::NetworkError.handle do
        raise OpenSSL::SSL::SSLError, 'message'
      end
    end.to raise_error(FixdUtils::NetworkError, 'message')

    expect do
      FixdUtils::NetworkError.handle do
        raise StandardError, 'message'
      end
    end.to raise_error(an_error_other_than(FixdUtils::NetworkError))
  end

  describe FixdUtils::NetworkError::Wrap do
    it 'should allow wrapping methods in network handler' do
      class Foo1
        include FixdUtils::NetworkError::Wrap

        handle_network_errors :raise_net_error, :raise_other_error

        def raise_net_error
          raise OpenSSL::SSL::SSLError, 'message'
        end

        def raise_other_error
          raise StandardError, 'message'
        end

        def raise_unwrapped_net_error
          raise OpenSSL::SSL::SSLError, 'message'
        end
      end

      expect { Foo1.new.raise_net_error }.to raise_error(FixdUtils::NetworkError)
      expect { Foo1.new.raise_other_error }.to raise_error(an_error_other_than(FixdUtils::NetworkError))
      expect { Foo1.new.raise_unwrapped_net_error }.to raise_error(an_error_other_than(FixdUtils::NetworkError))
    end

    it 'should work with modules' do
      module Foo2
        include FixdUtils::NetworkError::Wrap

        handle_network_errors :raise_net_error, :raise_other_error

        def raise_net_error
          raise OpenSSL::SSL::SSLError, 'message'
        end

        def raise_other_error
          raise StandardError, 'message'
        end

        def raise_unwrapped_net_error
          raise OpenSSL::SSL::SSLError, 'message'
        end
      end

      class Foo2Impl
        include Foo2
      end

      expect { Foo2Impl.new.raise_net_error }.to raise_error(FixdUtils::NetworkError)
      expect { Foo2Impl.new.raise_other_error }.to raise_error(an_error_other_than(FixdUtils::NetworkError))
      expect { Foo2Impl.new.raise_unwrapped_net_error }.to raise_error(an_error_other_than(FixdUtils::NetworkError))
    end

    it 'should work with extend-self modules' do
      module Foo3
        include FixdUtils::NetworkError::Wrap
        handle_network_errors :raise_net_error, :raise_other_error
        extend self

        def raise_net_error
          raise OpenSSL::SSL::SSLError, 'message'
        end

        def raise_other_error
          raise StandardError, 'message'
        end

        def raise_unwrapped_net_error
          raise OpenSSL::SSL::SSLError, 'message'
        end
      end

      expect { Foo3.raise_net_error }.to raise_error(FixdUtils::NetworkError)
      expect { Foo3.raise_other_error }.to raise_error(an_error_other_than(FixdUtils::NetworkError))
      expect { Foo3.raise_unwrapped_net_error }.to raise_error(an_error_other_than(FixdUtils::NetworkError))
    end
  end
end
