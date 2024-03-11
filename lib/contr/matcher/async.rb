# frozen_string_literal: true

module Contr
  class Matcher
    class Async < Matcher::Base
      def initialize(*)
        super

        @async = true
        @ok_rules = Concurrent::Array.new
        @failed_rules = Concurrent::Array.new
      end

      def match
        contract_future = main_pool.future do
          contract_failed = rules_pool ? check_with_async_rules : check_with_sync_rules

          dump_state! if contract_failed
        end

        contract_future.wait! if inline?
      end

      private

      def check_with_async_rules
        checked_rules = rules_pool.zip(
          *futures_from(guarantees),
          *futures_from(expectations)
        ).value!

        checked_guarantees, checked_expectations = checked_rules.partition { |rule| rule[:type] == :guarantee }

        guarantees_failed   = any_failed?(checked_guarantees)
        expectations_failed = all_failed?(checked_expectations)

        guarantees_failed || expectations_failed
      end

      def check_with_sync_rules
        any_failed?(guarantees) || all_failed?(expectations)
      end

      def futures_from(rules)
        rules.map do |rule|
          rules_pool.future(rule) do |rule|
            check_rule(rule)
          end
        end
      end

      # for testing purposes
      def inline?
        false
      end
    end
  end
end
