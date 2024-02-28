# frozen_string_literal: true

module Contr
  class Logger
    class Base
      def log(state)
        raise NotImplementedError, "logger should implement `#log` method"
      end
    end
  end
end
