# frozen_string_literal: true

module Contr
  class Sampler
    class Base
      def sample!(state)
        raise NotImplementedError, "sampler should implement `#sample!` method"
      end
    end
  end
end
