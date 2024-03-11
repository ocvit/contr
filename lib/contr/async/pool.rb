# frozen_string_literal: true

require "concurrent-ruby"

module Contr
  module Async
    module Pool
      class Base
        def executor
          @executor ||= create_executor
        end

        def create_executor
          raise NotImplementedError, "pool should implement `#create_executor` method"
        end

        def future(*args, &block)
          Concurrent::Promises.future_on(executor, *args, &block)
        end

        def zip(*futures)
          Concurrent::Promises.zip_futures_on(executor, *futures)
        end
      end
    end
  end
end
