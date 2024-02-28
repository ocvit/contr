# Contr

[![Gem Version](https://badge.fury.io/rb/contr.svg)](https://badge.fury.io/rb/contr)
[![Test](https://github.com/ocvit/contr/workflows/Test/badge.svg)](https://github.com/ocvit/contr/actions)
[![Coverage Status](https://coveralls.io/repos/github/ocvit/contr/badge.svg?branch=main)](https://coveralls.io/github/ocvit/contr?branch=main)

Minimalistic contracts in plain Ruby.

## Installation

Install the gem and add to Gemfile:

```sh
bundle add contr
```

Or install it manually:

```sh
gem install contr
```

## Terminology

Contract consists of rules of 2 types:

- guarantees - the ones that *__should__* be valid
- expectations - the ones that *__could__* be valid

Contract is called *__matched__* when:
- *__all__* guarantees are matched (if present)
- *__at least one__* expectation is matched (if present)

Rule is *__matched__* when it returns *__truthy__* value.\
Rule is *__not matched__* when it returns *__falsey__* value (`nil`, `false`) or *__raises an error__*.

Contract is triggered *__after__* operation under guard is succesfully executed.

## Usage

Example of basic contract:

```ruby
class PostRemovalContract < Contr::Act # or Contr::Base if you're a boring person
  guarantee :verified_via_api do |user_id, post_id, _|
    !API.post_exists?(user_id, post_id)
  end

  guarantee :verified_via_web do |*, post_url|
    !Web.post_exists?(post_url)
  end

  expect :removed_from_user_feed do |user_id, post_id, _|
    !Feed::User.post_exists?(user_id, post_id)
  end

  expect :removed_from_global_feed do |user_id, post_id, _|
    !Feed::Global.post_exists?(user_id, post_id)
  end
end

contract = PostRemovalContract.new
```

Contract check can be run in 2 modes: `sync` and `async`.

### Sync

In `sync` mode all rules are executed sequentially in the same thread with the operation.

If contract is matched - operation result is returned.

```ruby
api_response = contract.check(user_id, post_id, post_url) { API.delete_post(*some_args) }
# => {data: {deleted: true}}
```

If contract fails - the contract state is dumped via [Sampler](#Sampler), logged via [Logger](#Logger) and match error is raised:

```ruby
contract.check(*args) { operation }
# if one of the guarantees failed
# => Contr::Matcher::GuaranteesNotMatched: failed rules: [...], args: [...]

# if all expectations failed
# => Contr::Matcher::ExpectationsNotMatched: failed rules: [...], args: [...]
```

If operation raises an error it will be propagated right away, without triggering the contract itself:

```ruby
contract.check(*args) { raise StandardError, "some error" }
# => StandardError: some error
```

### Async

WIP

## Sampler

Default sampler creates marshalized dumps of contract state in specified folder with sampling period frequency:

```ruby
# state structure
{
  ts:            "2024-02-26T14:16:28.044Z",
  contract_name: "PostRemovalContract",
  failed_rules: [
    {type: :expectation, name: :removed_from_user_feed, status: :unexpected_error, error: error_instance},
    {type: :expectation, name: :removed_from_global_feed, status: :failed}
  ],
  ok_rules: [
    {type: :guarantee, name: :verified_via_api, status: :ok},
    {type: :guarantee, name: :verified_via_web, status: :ok}
  ],
  async:  false,
  args:   [1, 2, "url"],
  result: {data: {deleted: true}}
}

# default sampler can be reconfigured
ConfigedSampler = Contr::Sampler::Default.new(
  folder: "/tmp/contract_dumps",                       # default: "/tmp/contracts"
  path_template: "%<contract_name>_%<period_id>i.bin", # default: "%<contract_name>s/%<period_id>i.dump"
  period: 3600                                         # default: 600 (= 10 minutes)
)

class SomeContract < Contr::Act
  sampler ConfigedSampler

  # ...
end

# it will create dumps:
#   /tmp/contract_dumps/SomeContract_474750.bin
#   /tmp/contract_dumps/SomeContract_474751.bin
#   /tmp/contract_dumps/SomeContract_474752.bin
#   ...

# NOTE: `period_id` is calculated as <unix_ts> / `period`
```

Sampler is enabled by default:

```ruby
class SomeContract < Contr::Act
end

SomeContract.new.sampler
# => #<Contr::Sampler::Default:...>
```

It's possible to define custom sampler and use it instead:

```ruby
class CustomSampler < Contr::Sampler::Base
  # optional
  def initialize(*some_args)
    # ...
  end

  # required
  def sample!(state)
    # ...
  end
end

class SomeContract < Contr::Act
  sampler CustomSampler.new(*some_args)

  # ...
end
```

As well as to disable sampler completely:

```ruby
class SomeContract < Contr::Act
  sampler nil # or `false`
end
```

Default sampler also provides a helper method to read created dumps:

```ruby
contract.sampler
# => #<Contr::Sampler::Default:...>

# using absolute path
contract.sampler.read(path: "/tmp/contracts/SomeContract/474750.dump")
# => {ts: "2024-02-26T14:16:28.044Z", contract_name: "SomeContract", failed_rules: [...], ...}

# using `contract_name` + `period_id` args
# it uses `folder` and `path_template` from sampler config
contract.sampler.read(contract_name: "SomeContract", period_id: "474750")
# => {ts: "2024-02-26T14:16:28.044Z", contract_name: "SomeContract", failed_rules: [...], ...}
```

## Logger

Default logger logs contract state to specified stream in JSON format. State structure is the same as for sampler with a small addition of `tag` field.

```ruby
# state structure
{
  **sampler_state,
  tag: "contract-failed"
}

# default logger can be reconfigured
ConfigedLogger = Contr::Logger::Default.new(
  stream: $stderr,     # default: $stdout
  log_level: :warn,    # default: :debug
  tag: "shit-happened" # default: "contract-failed"
)

class SomeContract < Contr::Act
  logger ConfigedLogger

  # ...
end

# it will print:
# => W, [2024-02-27T14:36:53.607088 #58112]  WARN -- : {"ts":"...","contract_name":"...", ... "tag":"shit-happened"}
```

Logger is enabled by default:

```ruby
class SomeContract < Contr::Act
end

SomeContract.new.logger
# => #<Contr::Logger::Default:...>
```

It's possible to define custom logger in the same manner as with sampler:

```ruby
class CustomLogger < Contr::Sampler::Base
  # optional
  def initialize(*some_args)
    # ...
  end

  # required
  def log(state)
    # ...
  end
end

class SomeContract < Contr::Act
  logger CustomLogger.new(*some_args)

  # ...
end
```

As well as to disable logger completely:

```ruby
class SomeContract < Contr::Act
  logger nil # or `false`
end
```

## Configuration

Contracts can be deeply inherited:

```ruby
class SomeContract < Contr::Act
  guarantee :check_1 do
    # ...
  end

  expect :check_2 do
    # ...
  end
end
# guarantees:  check_1
# expecations: check_2
# sampler:     Contr::Sampler::Default
# logger:      Contr::Logger:Default

class OtherContract < SomeContract
  sampler CustomSampler.new

  guarantee :check_3 do
    # ...
  end
end
# guarantees:  check_1, check_3
# expecations: check_2
# sampler:     CustomSampler
# logger:      Contr::Logger:Default

class AnotherContract < OtherContract
  logger nil

  expect :check_4 do
    # ...
  end
end
# guarantees:  check_1, check_3
# expecations: check_2, check_4
# sampler:     CustomSampler
# logger:      nil
```

Contract can be configured using args passed to `.new` method:

```ruby
class SomeContract < Contr::Act
end

contract = SomeContract.new(sampler: CustomSampler.new, logger: CustomLogger.new)

contract.sampler
# => #<CustomSampler:...>

contract.logger
# => #<CustomLogger:...>
```

Rule block arguments are optional:

```ruby
class SomeContract < Contr::Act
  guarantee :args_used do |arg_1, arg_2|
    arg_1 # => 1
    arg_2 # => 2
  end

  guarantee :args_not_used do
    # ...
  end
end

SomeContract.new.check(1, 2) { operation }
```

Each rule has access to contract variables:

```ruby
class SomeContract < Contr::Act
  guarantee :check_1 do
    @args         # => [1, [2, 3], {key: :value}]
    @result       # => 2
    @contract     # => #<SomeContract:...>
    @guarantees   # => [{type: :guarantee, name: :check_1, block: #<Proc:...>}]
    @expectations # => []
    @sampler      # => #<Contr::Sampler::Default:...>
    @logger       # => #<Contr::Logger::Default:...>
  end
end

SomeContract.new.check(1, [2, 3], {key: :value}) { 1 + 1 }
```

Having access to `@result` can be really useful in contracts where operation produces a data that should be used inside the rules:

```ruby
class PostCreationContract < Contr::Act
  guarantee :verified_via_api do |user_id|
    post_id = @result["id"]
    API.post_exists?(user_id, post_id)
  end

  # ...
end

contract = PostCreationContract.new

contract.check(user_id) { API.create_post(*some_args) }
# => {"id":1050118621198921700, "text":"Post text", ...}
```

Having access to `@guarantees` and `@expectations` makes possible building dynamic contracts (in case you really need it):

```ruby
class SomeContract < Contr::Act
  guarantee :guarantee_1 do
    # add new guarantee to the end of guarantees list
    @guarantees << {
      type: :guarantee,
      name: :guarantee_2,
      block: proc do
        puts "guarantee 2"
        true
      end
    }

    puts "guarantee 1"
    true
  end

  expect :expect_1 do
    # add new expectation to the end of expectations list
    @expectations << {
      type: :expectation,
      name: :expect_2,
      block: proc do |*args|
        puts "expect 2, args: #{args}"
        true
      end
    }

    puts "expect 1"
    false
  end
end

SomeContract.new.check(1, 2) { operation }

# it will print:
# => guarantee 1
# => guarantee 2
# => expect 1
# => expect 2, args: [1, 2]
```

Other instance variables (e.g. `@args`, `@logger` etc.) can be modified on the fly too but make sure you really know what you do.

## TODO

- [x] Contract definition  
- [x] Sampler  
- [x] Logger  
- [x] Sync matcher  
- [ ] Async matcher  
- [ ] Add `before` block for contract definition  

## Development

```sh
bin/setup        # install deps
bin/console      # interactive prompt to play around
rake spec        # run tests
rake rubocop     # lint code
rake rubocop:md  # lint docs
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ocvit/contr.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
