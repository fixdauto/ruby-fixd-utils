# frozen_string_literal: true

require "spec_helper"

RSpec.describe NetworkError do
  examples = [
    [Net::OpenTimeout.new(""), true],
    [OpenSSL::SSL::SSLError.new(""), true],
    [StandardError.new(""), false],
    [ArgumentError.new(""), false]
  ]

  it "knows if an error is a network error" do
    examples.each do |err, result|
      expect(described_class.caused_by?(err)).to eq result
    end
  end

  it "allows handling of network errors by wrapping them" do
    expect do
      described_class.handle do
        raise OpenSSL::SSL::SSLError, "message"
      end
    end.to raise_error(described_class, "message")
  end

  it "does not wrap other errors" do
    expect do
      described_class.handle do
        raise StandardError, "message"
      end
    end.to raise_error(an_error_other_than(described_class))
  end

  describe NetworkError::Wrap do
    describe "class" do
      before do
        stub_const("Foo", Class.new do
          include NetworkError::Wrap

          attr_accessor :barf

          handle_network_errors :raise_net_error, :raise_other_error

          def raise_net_error
            raise OpenSSL::SSL::SSLError, "message"
          end

          def raise_other_error
            raise StandardError, "message"
          end

          def raise_unwrapped_net_error
            raise OpenSSL::SSL::SSLError, "message"
          end
        end)
      end

      it "wraps network errors" do
        expect { Foo.new.raise_net_error }.to raise_error(NetworkError)
      end

      it "does not wrap other errors" do
        expect { Foo.new.raise_other_error }.to raise_error(an_error_other_than(NetworkError))
      end

      it "does not wrap other methods" do
        expect { Foo.new.raise_unwrapped_net_error }.to raise_error(an_error_other_than(NetworkError))
      end
    end

    describe "modules" do
      before do
        stub_const("Foo", Module.new do
          include NetworkError::Wrap

          handle_network_errors :raise_net_error, :raise_other_error

          def raise_net_error
            raise OpenSSL::SSL::SSLError, "message"
          end

          def raise_other_error
            raise StandardError, "message"
          end

          def raise_unwrapped_net_error
            raise OpenSSL::SSL::SSLError, "message"
          end
        end)

        stub_const("FooImpl", Class.new do
          include const_get("Foo")
        end)
      end

      it "wraps network errors" do
        expect { FooImpl.new.raise_net_error }.to raise_error(NetworkError)
      end

      it "does not wrap other errors" do
        expect { FooImpl.new.raise_other_error }.to raise_error(an_error_other_than(NetworkError))
      end

      it "does not wrap other methods" do
        expect { FooImpl.new.raise_unwrapped_net_error }.to raise_error(an_error_other_than(NetworkError))
      end
    end

    describe "extend-self modules" do
      before do
        stub_const("Foo", Module.new do
          include NetworkError::Wrap
          handle_network_errors :raise_net_error, :raise_other_error
          extend self

          def raise_net_error
            raise OpenSSL::SSL::SSLError, "message"
          end

          def raise_other_error
            raise StandardError, "message"
          end

          def raise_unwrapped_net_error
            raise OpenSSL::SSL::SSLError, "message"
          end
        end)
      end

      it "wraps network errors" do
        expect { Foo.raise_net_error }.to raise_error(NetworkError)
      end

      it "does not wrap other errors" do
        expect { Foo.raise_other_error }.to raise_error(an_error_other_than(NetworkError))
      end

      it "does not wrap other methods" do
        expect { Foo.raise_unwrapped_net_error }.to raise_error(an_error_other_than(NetworkError))
      end
    end
  end
end
