# frozen_string_literal: true

require "spec_helper"

require "money"

RSpec.describe DataStruct do
  before(:all) do
    Time.zone = "UTC"
  end

  context "simple example" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes a: String, b: Integer, c: Float

        def cat
          a + b.to_s
        end
      end)
    end

    let(:params) do
      { a: "A", b: 1, c: nil, d: "D" }
    end

    let(:foo) { Foo.new(params) }

    it "allows creating new data structs" do
      expect(foo.a).to eq "A"
      expect(foo.b).to eq 1
    end

    it "allows custom methods" do
      expect(foo.cat).to eq "A1"
    end

    it "ignores undefined properties" do
      expect(foo.respond_to?(:d)).to eq false
      expect { foo.d }.to raise_error(NoMethodError)
    end

    it "allows nils" do
      expect(foo.c).to be_nil
    end

    it "nils missing attributes" do
      expect(Foo.new({}).a).to be_nil
    end

    it "knows the name of the class" do
      expect(Foo.name).to eq "Foo"
    end

    it "checks equality by value" do
      expect(Foo.new(params)).to eq foo
    end

    describe "copy" do
      let(:copy) { foo.copy(a: "B") }

      it "allows updating parameters by creating new instances" do
        expect(copy.a).to eq "B"
        expect(copy).not_to eq foo
      end
    end
  end

  describe "getters" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes a: String, b: Integer

        def b
          @b + 1
        end
      end)
    end

    let(:foo) { Foo.new(a: "A", b: 1, c: "C") }

    it "allows overriding getters" do
      expect(foo.b).to eq 2
    end

    it "serializes to the original properties" do
      # NOTE: this potentially suprising behavior!
      expect(foo.as_json["a"]).to eq "A"
      expect(foo.as_json["b"]).to eq 1
      expect(foo.as_json["c"]).to eq "C"
      # ... but this is why:
      expect(Foo.new(foo.as_json)).to eq foo
      expect(Foo.new(foo.as_json).as_json).to eq foo.as_json
    end

    it "does not allow properties to be mutated" do
      # because it will serialize to the original params, these
      # should be immutable objects
      expect { foo.a = "B" }.to raise_error(NoMethodError)
    end

    context "getter for a set property" do
      before do
        stub_const("Foo2", Class.new(DataStruct::Base) do
          define_attributes(a: String)
          def b
            "something"
          end
        end)
      end

      it "allows parsing an object with a property overridden by a method" do
        expect(Foo2.new(a: "A", b: "B").b).to eq "something" # not 'B'
      end
    end
  end

  describe "booleans" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes sold: DataStruct::Boolean,
                          is_free: DataStruct::Boolean,
                          has_exploded: DataStruct::Boolean
      end)
    end

    let(:foo) { Foo.new(sold: true, is_free: false, has_exploded: true) }

    it "allows accessing the boolean fields under the original name" do
      expect(foo.sold).to eq true
      expect(foo.is_free).to eq false
      expect(foo.has_exploded).to eq true
    end

    it "adds ?-accessor methods for booleans" do
      expect(foo.sold?).to eq true
      expect(foo.free?).to eq false
      expect(foo.exploded?).to eq true
      expect(foo).to be_sold
    end
  end

  describe "conversions" do
    context "built-in" do
      before do
        stub_const("Foo", Class.new(DataStruct::Base) do
          define_attributes a: Integer, b: Date, c: ActiveSupport::TimeWithZone
        end)
      end

      let(:foo) { Foo.new(a: "-100", b: "2021-01-01", c: "2021-12-15T18:31:45.884Z") }

      it "converts strings to integers" do
        expect(foo.a).to eq(-100)
      end

      it "converts strings to dates" do
        expect(foo.b).to be_a(Date)
        expect(foo.b.to_s).to eq "2021-01-01"
      end

      it "converts strings to datetimes" do
        expect(foo.c).to be_a(ActiveSupport::TimeWithZone)
        expect(foo.c.to_f).to eq 1_639_593_105.884
      end
    end

    context "custom" do
      before do
        stub_const("Foo", Class.new(DataStruct::Base) do
          define_attributes a: Money, b: Symbol
          convert Float, to: Money, with: ->(v) { Money.new(v * 100, "USD") }
          convert String, to: Symbol, with: :to_sym
        end)
      end

      let(:foo) { Foo.new(a: 19.99, b: "foo") }

      it "allows custom type conversions using lambdas" do
        expect(foo.a).to be_a(Money)
        expect(foo.a.amount).to eq 19.99
        expect(foo.a.currency).to eq "USD"
      end

      it "allows custom type conversions using method symbols" do
        expect(foo.b).to eq :foo
      end
    end

    context "overriding" do
      before do
        stub_const("Foo", Class.new(DataStruct::Base) do
          define_attributes a: Integer
          convert String, to: Integer, with: lambda { |v|
            base, exponent = v.split("^").map(&:to_i)
            base**exponent
          }
        end)
      end

      let(:foo) { Foo.new(a: "3^2") }

      it "allows built-in type conversions to be overridden" do
        expect(foo.a).to eq 9
      end
    end
  end

  describe "verifications" do
    context "invalid types" do
      before do
        stub_const("Foo", Class.new(DataStruct::Base) do
          define_attributes(a: String)
        end)
      end

      it "verifies types" do
        expect { Foo.new(a: %w[an array]) }.to raise_error(DataStruct::InvalidParameterError)
      end
    end
  end

  context "booleans" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes(bool: DataStruct::Boolean)
      end)
    end

    it "verifies booleans" do
      expect(Foo.new(bool: true).bool).to eq true
      expect(Foo.new(bool: false).bool).to eq false
      expect { Foo.new(bool: %w[an array]) }.to raise_error(DataStruct::InvalidParameterError)
    end
  end

  context "enums" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes enum: DataStruct::Enum.new(%w[active expired])
      end)
    end

    it "allows enums" do
      expect(Foo.new(enum: "active").enum).to eq "active"
    end

    it "verifies enums" do
      expect { Foo.new(enum: "inactive") }.to raise_error(DataStruct::InvalidParameterError)
    end
  end

  context "post-conversion" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes a: Symbol
        convert String, to: Symbol, with: :to_s
      end)
    end

    it "verifies the post-conversion types, not the pre-conversion types" do
      expect { Foo.new(a: "sym") }.to raise_error(DataStruct::InvalidParameterError)
    end
  end

  describe "arrays" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes names: [String],
                          numbers: [Integer]
      end)
    end

    let(:names) { %w[john jacob jingleheimer shmitt] }
    let(:foo) { Foo.new(names: names, numbers: %w[1 2 3]) }

    it "allows declaring something to be an array of primitives" do
      expect(foo.names).to eq names
    end

    it "allows type conversions for arrays" do
      expect(foo.numbers).to eq [1, 2, 3]
    end

    it "verifies that arrays are arrays" do
      expect { Foo.new(names: "not an array") }.to raise_error(DataStruct::InvalidParameterError)
    end

    it "verifies that the types within the arrays match" do
      expect { Foo.new(names: [1]) }.to raise_error(DataStruct::InvalidParameterError)
    end
  end

  context "nested arrays" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes matrix: [[Integer]]
      end)
    end

    let(:identity) do
      [
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1]
      ]
    end

    let(:foo) { Foo.new(matrix: identity) }

    it "supports nested arrays" do
      expect(foo.matrix).to eq identity
    end
  end

  describe "nested objects" do
    let(:email) { "julian@fixdapp.com" }
    let(:subscription) { Subscription.new(id: 1, customer: { id: 1, email: email }) }

    describe "referenced" do
      before do
        stub_const("Customer", Class.new(DataStruct::Base) do
          define_attributes id: Integer, email: String
        end)

        stub_const("Subscription", Class.new(DataStruct::Base) do
          define_attributes id: Integer, customer: Customer
        end)
      end

      it "allows defining nested objects" do
        expect(subscription.customer.id).to eq 1
        expect(subscription.customer.email).to eq email
      end

      it "knows the class name for nested objects" do
        expect(subscription.customer.class.name).to eq "Customer"
      end

      it "serializes objects with nested objects" do
        expect(subscription.as_json).to eq({
                                             "id" => 1,
                                             "customer" => {
                                               "id" => 1,
                                               "email" => email
                                             }
                                           })
      end
    end

    context "inline" do
      before do
        stub_const("Subscription", Class.new(DataStruct::Base) do
          define_attributes id: Integer,
                            customer: define("Customer", id: Integer, email: String)
        end)
      end

      it "allows defining nested objects" do
        expect(subscription.customer.id).to eq 1
        expect(subscription.customer.email).to eq email
      end

      it "knows the class name for nested objects" do
        expect(subscription.customer.class.name).to eq "Subscription::Customer"
      end

      it "serializes objects with nested objects" do
        expect(subscription.as_json).to eq({
                                             "id" => 1,
                                             "customer" => {
                                               "id" => 1,
                                               "email" => email
                                             }
                                           })
      end

      it "defines a new constant for the inner class" do
        expect { Subscription::Customer }.not_to raise_error
      end
    end
  end

  context "deeply nested objects" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes a: define("A", b: define("B", c: Integer))
      end)
    end

    let(:foo) { Foo.new(a: { b: { c: 1 } }) }

    it "supports deeply-nested objects" do
      expect(foo.a.b.c).to eq 1
    end

    it "defines constants for nested classes" do
      expect(foo.a.class.name).to eq "Foo::A"
      expect(foo.a.b.class.name).to eq "Foo::B"
      expect { [Foo::A, Foo::B] }.not_to raise_error
    end
  end

  context "objects in arrays" do
    before do
      stub_const("Order", Class.new(DataStruct::Base) do
        define_attributes id: Integer
        define_attributes transactions: [define("Transaction",
                                                id: Integer,
                                                amount: Float)]
      end)
    end

    let(:order) do
      Order.new(id: 1, transactions: [
                  { id: 1, amount: 19.99 },
                  { id: 2, amount: 3.50 }
                ])
    end

    it "supports objects nested in arrays" do
      expect(order.transactions[0].id).to eq 1
      expect(order.transactions[1].amount).to eq 3.50
    end

    it "defines constants for nested classes" do
      expect(order.transactions[0].class.name).to eq "Order::Transaction"
      expect { Order::Transaction }.not_to raise_error
    end
  end

  context "conversion inheritance" do
    let(:foo) { Foo.new(a: "19.99", b: { c: "3.50" }) }

    describe "referenced" do
      # rubocop:disable Lint/ConstantDefinitionInBlock
      before do
        class Foo < DataStruct::Base
          convert String, to: Money, with: ->(v) { Money.new(v.to_f * 100, "USD") }

          class Bar < DataStruct::Base
            define_attributes c: Money
          end

          define_attributes a: Money, b: Bar
        end
      end

      after do
        Foo.send(:remove_const, "Bar")
        Object.send(:remove_const, "Foo")
      end
      # rubocop:enable Lint/ConstantDefinitionInBlock

      it "allows inheriting converters from containing structures" do
        expect(foo.b.c).to be_a(Money)
        expect(foo.b.c.amount).to eq 3.50
      end
    end
  end

  describe "inline" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        convert String, to: Money, with: ->(v) { Money.new(v.to_f * 100, "USD") }

        define_attributes a: Money, b: define("Bar", c: Money)
      end)
    end

    let(:foo) { Foo.new(a: "19.99", b: { c: "3.50" }) }

    it "allows inheriting converters from containing structures" do
      expect(foo.b.c).to be_a(Money)
      expect(foo.b.c.amount).to eq 3.50
    end
  end

  describe "param keys" do
    before do
      stub_const("Foo", Class.new(DataStruct::Base) do
        define_attributes a: String,
                          b: Integer,
                          c: [DataStruct::Boolean],
                          d: DataStruct::Enum.new(%w[a b c]),
                          e: define("Nested",
                                    a: String,
                                    b: define("SubNested", c: String)),
                          f: [define("ArrayNested", a: String)]
      end)
    end

    it "should return the parameter keys" do
      expect(Foo.param_keys).to eq(
        [
          "a", "b", { "c" => [] }, "d", { "e" => ["a", { "b" => ["c"] }] }, { "f" => ["a"] }
        ]
      )
    end
  end
end
