# frozen_string_literal: true

require "forwardable"
require "time"

module Contr
  class Matcher
    class RulesNotMatched < StandardError
      def initialize(failed_rules, args)
        @failed_rules_minimized = failed_rules.map(&:values)
        @args = args
      end

      def message
        "failed rules: #{@failed_rules_minimized.inspect}, args: #{@args.inspect}"
      end
    end

    class GuaranteesNotMatched < RulesNotMatched
    end

    class ExpectationsNotMatched < RulesNotMatched
    end

    class Base
      extend Forwardable

      def_delegators :@contract, :logger, :sampler, :main_pool, :rules_pool, :guarantees, :expectations

      def initialize(contract, args, result)
        @contract = contract
        @args     = args.freeze
        @result   = result.freeze
      end

      def match
        raise NotImplementedError, "matcher should implement `#match` method"
      end

      private

      def any_failed?(rules)
        rules.any? { |rule| rule_failed?(rule) }
      end

      def all_failed?(rules)
        !rules.empty? && rules.all? { |rule| rule_failed?(rule) }
      end

      def rule_failed?(rule)
        rule = check_rule(rule) unless rule.key?(:status)

        if rule[:status] == :ok
          @ok_rules << rule
          false
        else
          @failed_rules << rule
          true
        end
      end

      def check_rule(rule)
        status_data = call_rule(rule)
        rule.slice(:type, :name).merge(status_data)
      end

      def call_rule(rule)
        block = rule[:block]

        block_result = block.parameters.empty? ? block.call : block.call(@args, @result)
        block_result ? {status: :ok} : {status: :failed}
      rescue => error
        {status: :unexpected_error, error: error}
      end

      def dump_state!
        if sampler
          dump_info = sampler.sample!(state)
          state[:dump_info] = dump_info if dump_info
        end

        logger&.log(state)
      end

      def state
        @state ||= {
          ts:            Time.now.utc.iso8601(3),
          contract_name: @contract.name,
          failed_rules:  @failed_rules,
          ok_rules:      @ok_rules,
          async:         @async,
          args:          @args,
          result:        @result
        }
      end
    end
  end
end
