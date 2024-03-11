# frozen_string_literal: true

module Contr
  module Async
    module Pool
      class Fixed < Pool::Base
        def initialize(max_threads: Concurrent.processor_count)
          @max_threads = max_threads
        end

        def create_executor
          Concurrent::ThreadPoolExecutor.new(
            min_threads:     0,
            max_threads:     @max_threads,
            auto_terminate:  true,
            idletime:        60,           # 1 minute
            max_queue:       0,            # unlimited
            fallback_policy: :caller_runs  # doesn't matter - max_queue 0
          )
        end
      end
    end
  end
end
