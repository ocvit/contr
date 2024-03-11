# frozen_string_literal: true

RSpec::Matchers.define :be_fixed_async_pool do |opts = {}|
  match do |actual|
    max_threads = opts[:max_threads] || Concurrent.processor_count

    actual.instance_of?(Contr::Async::Pool::Fixed) \
      && actual.executor.max_length == max_threads \
      && actual.executor.min_length == 0
  end
end
