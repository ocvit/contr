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
class SumContract < Contr::Act # or Contr::Base if you're a boring person
  guarantee :result_is_positive_float do |(_), result|
    result.is_a?(Float) && result > 0
  end

  guarantee :args_are_numbers do |args|
    args.all?(Numeric)
  end

  expect :arg_1_is_float do |(arg_1, _)|
    arg_1.is_a?(Float)
  end

  expect :arg_2_is_float do |(_, arg_2)|
    arg_2.is_a?(Float)
  end
end

args = [1, 2.0]
contract = SumContract.new

contract.check(*args) { args.inject(:+) }
# => 3.0
```

Contract check can be run in 2 modes: `sync` and `async`.

### Sync

In `sync` mode rules are executed sequentially in the same thread with the operation.

If contract matched - operation result is returned afterwards:

```ruby
contract.check(*args) { 1 + 1 }
# => 2
```

If contract failed - contract state is dumped via [Sampler](#Sampler), logged via [Logger](#Logger) and match error is raised:

```ruby
contract.check(*args) { 1 + 1 }
# when one of the guarantees failed
# => Contr::Matcher::GuaranteesNotMatched: failed rules: [...], args: [...]

# when all expectations failed
# => Contr::Matcher::ExpectationsNotMatched: failed rules: [...], args: [...]
```

If operation raises an error it will be propagated right away, without triggering the contract itself:

```ruby
contract.check(*args) { raise StandardError, "some error" }
# => StandardError: some error
# (no state dump, no log)
```

### Async

In `async` mode rules are executed in a separate thread. Operation result is returned immediately regardless of contract match status:

```ruby
contract.check_async(*args) { 1 + 1 }
# => 2
# (contract is still being checked in a background)
#
# if contract matched - nothing additional happens
# if contract failed - state is dumped and logged as with `#check`
```

If operation raises an error it will be propagated right away, without triggering the contract itself:

```ruby
contract.check_async(*args) { raise StandardError, "some error" }
# => StandardError: some error
# (no state dump, no log)
```

Each contract instance can work with 2 dedicated thread pools:

- `main` - to execute contract checks asynchronously (always present)
- `rules` - to execute rules asynchronously (not set by default)

There are couple of predefined pool primitives that can be used:

```ruby
# fixed
# - works as a fixed pool of size: 0..max_threads
# - max_threads == vCPU cores, but can be overridden
# - similar to `fast` provided by `concurrent-ruby`, but is not global
Contr::Async::Pool::Fixed.new
Contr::Async::Pool::Fixed.new(max_threads: 9000)

# io (global)
# - provided by `concurrent-ruby`
# - works as a dynamic pool of almost unlimited size (danger!)
# - quote: "recommended for long tasks with blocking I/O operations"
Contr::Async::Pool::GlobalIO.new
```

Default contract `async` config looks like this:

```ruby
class SomeContract < Contr::Act
  async pools: {
    main: Contr::Async::Pool::Fixed.new,
    rules: nil # disabled, rules are executed synchronously
  }
end
```

To enable asynchronous execution of rules:

```ruby
class SomeContract < Contr::Act
  async pools: {
    rules: Contr::Async::Pool::GlobalIO.new # or any other pool
  }
end
```

> [!NOTE]
> Asynchronous execution of rules forces to check them all, not the smallest scope possible as with regular sequential execution. Make sure that potential extra calls to DB/network are OK (if they have place).

It's also possible to define custom pool:

```ruby
class CustomPool < Contr::Async::Pool::Base
  # optional
  def initialize(*some_args)
    # ...
  end

  # required!
  def create_executor
    Concurrent::ThreadPoolExecutor.new(
      min_threads: 0,
      max_threads: 1234
      # ...other opts
    )
  end
end

class SomeContract < Contr::Act
  async pools: {
    main: CustomPool.new(*some_args)
  }
end
```

Comparison of different pools configurations can be checked in [Benchmarks](#Benchmarks) section.

## Sampler

Default sampler creates marshalized dumps of contract state in specified folder with sampling period frequency:

```ruby
# state structure
{
  ts:            "2024-02-26T14:16:28.044Z",
  contract_name: "SumContract",
  failed_rules: [
    {type: :expectation, name: :arg_1_is_float, status: :failed},
    {type: :expectation, name: :arg_2_check_that_raises, status: :unexpected_error, error: error_instance}
  ],
  ok_rules: [
    {type: :guarantee, name: :result_is_positive_float, status: :ok},
    {type: :guarantee, name: :args_are_numbers, status: :ok}
  ],
  async:  false,
  args:   [1, 2.0],
  result: 3.0
}

# default sampler can be reconfigured
ConfigedSampler = Contr::Sampler::Default.new(
  folder: "/tmp/contract_dumps",                         # default: "/tmp/contracts"
  path_template: "%<contract_name>s_%<period_id>i.bin",  # default: "%<contract_name>s/%<period_id>i.dump"
  period: 3600                                           # default: 600 (= 10 minutes)
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

  # required!
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

Default logger logs contract state to specified stream in JSON format. State structure is the same as in sampler plus additional `tag` field:

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

  # required!
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

Contract can be configured using arguments passed to `.new` method:

```ruby
class SomeContract < Contr::Act
end

contract = SomeContract.new(
  async: {pools: {main: OtherPool.new, rules: AnotherPool.new}},
  sampler: CustomSampler.new,
  logger: CustomLogger.new
)

contract.main_pool
# => #<OtherPool:...>

contract.rules_pool
# => #<AnotherPool:...>

contract.sampler
# => #<CustomSampler:...>

contract.logger
# => #<CustomLogger:...>
```

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
# async:       pools: {main: <fixed>, rules: nil}
# sampler:     Contr::Sampler::Default
# logger:      Contr::Logger:Default

class OtherContract < SomeContract
  async pools: {rules: Contr::Async::Pool::GlobalIO.new}
  sampler CustomSampler.new

  guarantee :check_3 do
    # ...
  end
end
# guarantees:  check_1, check_3
# expecations: check_2
# async        pools: {main: <fixed>, rules: <global_io>}
# sampler:     CustomSampler
# logger:      Contr::Logger:Default

class AnotherContract < OtherContract
  async pools: {main: Contr::Async::Pool::GlobalIO.new}
  logger nil

  expect :check_4 do
    # ...
  end
end
# guarantees:  check_1, check_3
# expecations: check_2, check_4
# async        pools: {main: <global_io>, rules: <global_io>}
# sampler:     CustomSampler
# logger:      nil
```

Rule block arguments can be accessed in different ways:

```ruby
class SomeContract < Contr::Act
  guarantee :all_args_used do |(arg_1, arg_2), result|
    arg_1  # => 1
    arg_2  # => 2
    result # => 3
  end

  guarantee :result_ignored do |(arg_1, arg_2)|
    arg_1  # => 1
    arg_2  # => 2
  end

  guarantee :check_args_ignored do |(_), result|
    result # => 3
  end

  guarantee :args_not_used do
    # ...
  end
end

SomeContract.new.check(1, 2) { 1 + 2 }
```

Having access to `result` can be really useful in contracts where operation produces a data that must be used inside the rules:

```ruby
class PostCreationContract < Contr::Act
  guarantee :verified_via_api do |(user_id), result|
    post_id = result["id"]
    API.post_exists?(user_id, post_id)
  end

  # ...
end

contract = PostCreationContract.new
contract.check(user_id) { API.create_post(*some_args) }
# => {"id":1050118621198921700, "text":"Post text", ...}
```

Contract instances are fully isolated from check invocations and can be safely cached:

```ruby
module Contracts
  PostRemoval         = PostRemovalContract.new
  PostRemovalNoLogger = PostRemovalContract.new(logger: nil)

  # ...
end

posts.each do |post|
  Contracts::PostRemovalNoLogger.check_async(*args) { delete_post(post) }
end
```

## Examples

Examples can be found [here](https://github.com/ocvit/contr/tree/main/examples).

## Benchmarks

Comparison of different pool configs for [I/O blocking](https://github.com/ocvit/contr/blob/main/benchmarks/io_task.rb) and [CPU intensive](https://github.com/ocvit/contr/blob/main/benchmarks/cpu_task.rb) tasks can be found in [benchmarks](https://github.com/ocvit/contr/tree/main/benchmarks) folder.

## TODO

- [x] Contract definition  
- [x] Sampler  
- [x] Logger  
- [x] Sync matcher  
- [x] Async matcher  
- [ ] Add `before` block for rules variables pre-initialization
- [ ] Add `meta` hash to have ability to capture additional debug data from within the rules

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

## Credits

- [simple_contracts](https://github.com/bibendi/simple_contracts) by [bibendi](https://github.com/bibendi)
- [poro_contract](https://github.com/sclinede/poro_contract/) by [sclinede](https://github.com/sclinede)
