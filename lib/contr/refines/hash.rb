# frozen_string_literal: true

module Refines
  module Hash
    refine ::Hash do
      def deep_merge(other_hash)
        merge(other_hash) do |_key, this_value, other_value|
          if this_value.is_a?(::Hash) && other_value.is_a?(::Hash)
            this_value.deep_merge(other_value)
          else
            other_value
          end
        end
      end
    end
  end
end
