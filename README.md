# Fixd Utils

This is a collection of small utility classes that are useful in Ruby and Rails applications at FIXD. 

## Base32

```ruby
Base32.secure_generate(8) # "D68SSNJ4"
```

## ActiveRecordExtensions

```ruby
# Avoid race conditions on unique constraints
ActiveRecordExtensions.retry_on_conflict do
    User.find_or_create_by!(email: email)
end

charge = Charge.create!
ActiveRecord::Base.transaction do
  order = Order.create(charge: charge)
  begin
    Gateway.execute_sale!(charge)
    charge.update!(state: :settled)
  rescue ChargeError
    # Execute a database operation even if transaction is rolled back
    ActiveRecordExtensions.execute_outside_transaction do
      charge.update!(state: :declined)
    end
    raise
  end
  after_commit { OrderMailer.receipt(order).deliver_later }
end
```

## NetworkError

A wrapper error class for common transient network issues.

```ruby
NetworkError.handle do
    Net::HTTP.get('/some-path') # if this raises e.g. Net::ReadTimeout...
end # ... this will raise NetworkError.new(cause: Net::ReadTimeout)

class Api
    include NetworkError::Wrap # can also be used as a method decorator

    handle_network_errors :update_user

    def update_user(params)
        HTTPParty.post('/users', body: params.to_json)
    end
end
```

## DurationAttributes

Helper for duration values in ActiveRecord fields.

```ruby
class Foo < ActiveModel::Model
  include DurationAttributes
  attr_accessor :trial_period_seconds
  duration_attribute :trial_period, unit: :seconds
end
foo = Foo.new(trial_period_seconds: 60)
foo.trial_period # 1.minute
foo.trial_period = 1.year
foo.trial_period # 1.year
foo.trial_period_seconds # 31556952
foo.trial_period = 'P3M'
foo.trial_period # 3.months
foo.trial_period_seconds # 7889238
```

## DataStruct

Immutable, declarative, struct classes for wrapping hashes. Useful
for serializing and adding logic to 3rd-party API response objects.

```ruby
class Foo < DataStruct::Base
  define_attributes id: Integer,
    name: String,
    admin: DataStruct::Boolean, # special case, since Ruby doesn't have a boolean class
    tags: [String] # primitive arrays

  define_attributes  score: Float, # you can call define-attributes multiple times
    registered_at: ActiveSupport::TimeWithZone,
    next_bill_on: Date, # date and time type conversions
    state: DataStruct::Enum.new(['pending', 'active', 'expired']) # enums
    address: define('Address', # nested in-line objects, defines a Foo::Address class
      street: String,
      city: String,
      state: String,
      zip: String
    )
  class Transaction < DataStruct::Base
    define_attributes id: Integer, amount: Money # conversions can be inherited from containing classes
  end

  define_attributes transactions: [Transaction] # nested object arrays, also works in-line

  # Basic conversions like dates and times are automatically supported.
  # You can define additional conversions with this constant, mapping
  # from and to types to a lambda:
  convert Float, to: Money, with: lambda { |v| v.to_money('USD') }

  def priority? # custom methods
    tags.include?('priority')
  end
end
foo = Foo.new(json_representation)
foo.transactions[0].money
foo.admin?
foo.to_hash == json_representation
Foo.new(json_representation) == foo
new_foo = foo.copy(is_admin: false)
# Permit ActionController::Parameters with all nested, defined keys
Foo.new(params.require(:foo).permit(*Foo.param_keys))
# Where they can't be inferred (such as with custom converters),
# can explicitly specify parameters to permit using `permit`:
class Order
  define_attributes order_id: String,
                    total_price: Money
  convert Hash, to: Money, with: lambda { |v| v['amount'].to_money(v['currency']) }
  permit total_price: [:amount, :currency]
end
params.permit(*Order.param_keys) # [:order_id, { total_price: [:amount, :currency] }]
```

## UriBuilder

```ruby
UriBuilder.build(
    host: 'https://google.com',
    path: '/',
    query: { q: 'fixd automotive' }
) # URI('https://google.com/?q=fixd+automotive')
```

## GlobalLock

A Redis-backed mutex that can cross process boundaries.

```ruby
GlobalLock.acquire("some-lock-key") do
    # can trust only one ruby process is in this block for the same key at a time
end
```
