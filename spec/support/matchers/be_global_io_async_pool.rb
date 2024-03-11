# frozen_string_literal: true

RSpec::Matchers.define :be_global_io_async_pool do
  match do |actual|
    actual.instance_of?(Contr::Async::Pool::GlobalIO) && actual.executor == Concurrent.global_io_executor
  end
end
