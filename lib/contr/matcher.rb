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
      def initialize(contract, args, result)
        @contract = contract
        @args     = args
        @result   = result

        # def_delegators would be slickier but it breaks consistency of
        # variables names when used within the rules definitions
        @guarantees   = @contract.guarantees
        @expectations = @contract.expectations
        @sampler      = @contract.sampler
        @logger       = @contract.logger
      end

      def match
        raise NotImplementedError, "matcher should implement `#match` method"
      end

      private

      def match_rule(rule)
        block = rule[:block]

        block_result = instance_exec(*@args, &block)
        block_result ? {status: :ok} : {status: :failed}
      rescue => error
        {status: :unexpected_error, error: error}
      end

      def dump_state!
        state = compile_state

        if @sampler
          dump_info = @sampler.sample!(state)
          state[:dump_info] = dump_info if dump_info
        end

        @logger&.log(state)
      end

      def compile_state
        {
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
