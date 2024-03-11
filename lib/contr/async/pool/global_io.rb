# frozen_string_literal: true

module Contr
  module Async
    module Pool
      class GlobalIO < Pool::Base
        def create_executor
          Concurrent.global_io_executor
        end
      end
    end
  end
end
