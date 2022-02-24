# Fixd Utils

This is a collection of small utility classes that are useful in Ruby and Rails applications at FIXD. 

## Base32

```ruby
Base32.secure_generate(8) # "D68SSNJ4"
```

## ActiveRecordExtensions

```ruby
ActiveRecordExtensions.retry_on_conflict do
    User.find_or_create_by!(email: email)
end
```

## NetworkError

A wrapper error class for common transient network issues.

```ruby
NetworkError.wrap do
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
GlobalLock.aquire("some-lock-key") do
    # can trust only one ruby process is in this block for the same key at a time
end
```
