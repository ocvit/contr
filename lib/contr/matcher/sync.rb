# frozen_string_literal: true

module Contr
  class Matcher
    class Sync < Matcher::Base
      def initialize(*)
        super

        @async = false
        @ok_rules = []
        @failed_rules = []
      end

      def match
        any_failed?(guarantees)   && dump_state_and_raise(GuaranteesNotMatched)
        all_failed?(expectations) && dump_state_and_raise(ExpectationsNotMatched)
      end

      private

      def dump_state_and_raise(error_class)
        dump_state!

        raise error_class.new(@failed_rules, @args)
      end
    end
  end
end
