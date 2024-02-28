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
        guarantees_matched?   || dump_state_and_raise(GuaranteesNotMatched)
        expectations_matched? || dump_state_and_raise(ExpectationsNotMatched)
      end

      private

      def guarantees_matched?
        return true if @guarantees.empty?

        @guarantees.all? { |rule| ok_rule?(rule) }
      end

      def expectations_matched?
        return true if @expectations.empty?

        @expectations.any? { |rule| ok_rule?(rule) }
      end

      def ok_rule?(rule)
        match_result = match_rule(rule)
        checked_rule = rule.slice(:type, :name).merge!(match_result)

        if match_result[:status] == :ok
          @ok_rules << checked_rule
          true
        else
          @failed_rules << checked_rule
          false
        end
      end

      def dump_state_and_raise(error_class)
        dump_state!

        raise error_class.new(@failed_rules, @args)
      end
    end
  end
end
