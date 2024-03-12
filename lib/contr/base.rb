# frozen_string_literal: true

module Contr
  class Base
    class << self
      attr_reader :config, :guarantees, :expectations

      def async(async)
        set_config(:async, async)
      end

      def logger(logger)
        set_config(:logger, logger)
      end

      def sampler(sampler)
        set_config(:sampler, sampler)
      end

      def guarantee(name, &block)
        add_guarantee(name, block)
      end

      def expect(name, &block)
        add_expectation(name, block)
      end

      private

      def set_config(key, value)
        @config ||= {}
        @config[key] = value
      end

      def add_guarantee(name, block)
        @guarantees ||= []
        @guarantees << {type: :guarantee, name: name, block: block}
      end

      def add_expectation(name, block)
        @expectations ||= []
        @expectations << {type: :expectation, name: name, block: block}
      end
    end

    attr_reader :config, :logger, :sampler, :main_pool, :rules_pool, :guarantees, :expectations

    def initialize(instance_config = {})
      @config = merge_configs(instance_config)

      init_logger!
      init_sampler!
      init_main_pool!
      init_rules_pool!

      aggregate_guarantees!
      aggregate_expectations!

      freeze
    end

    def check(*args)
      result = yield
      Matcher::Sync.new(self, args, result).match
      result
    end

    def check_async(*args)
      result = yield
      Matcher::Async.new(self, args, result).match
      result
    end

    def name
      self.class.name
    end

    private

    using Refines::Hash

    def merge_configs(instance_config)
      configs = contracts_chain.filter_map(&:config)
      configs << instance_config

      merged = configs.inject(&:deep_merge) || {}
      merged.freeze
    end

    def init_logger!
      @logger =
        case config
        in logger: nil | false
          nil
        in logger: Logger::Base => custom_logger
          custom_logger
        in logger: invalid_logger
          raise ArgumentError, "logger should be inherited from Contr::Logger::Base or be falsy, received: #{invalid_logger.inspect}"
        else
          Logger::Default.new
        end
    end

    def init_sampler!
      @sampler =
        case config
        in sampler: nil | false
          nil
        in sampler: Sampler::Base => custom_sampler
          custom_sampler
        in sampler: invalid_sampler
          raise ArgumentError, "sampler should be inherited from Contr::Sampler::Base or be falsy, received: #{invalid_sampler.inspect}"
        else
          Sampler::Default.new
        end
    end

    def init_main_pool!
      @main_pool =
        case config.dig(:async, :pools)
        in main: nil | false
          raise ArgumentError, "main pool can't be disabled"
        in main: Async::Pool::Base => custom_pool
          custom_pool
        in main: invalid_pool
          raise ArgumentError, "main pool should be inherited from Contr::Async::Pool::Base, received: #{invalid_pool.inspect}"
        else
          Async::Pool::Fixed.new
        end
    end

    def init_rules_pool!
      @rules_pool =
        case config.dig(:async, :pools)
        in rules: nil | false
          nil
        in rules: Async::Pool::Base => custom_pool
          custom_pool
        in rules: invalid_pool
          raise ArgumentError, "rules pool should be inherited from Contr::Async::Pool::Base or be falsy, received: #{invalid_pool.inspect}"
        else
          nil
        end
    end

    def aggregate_guarantees!
      @guarantees = aggregate_rules(:guarantees).freeze
    end

    def aggregate_expectations!
      @expectations = aggregate_rules(:expectations).freeze
    end

    def aggregate_rules(rule_type)
      contracts_chain.flat_map(&rule_type).compact
    end

    def contracts_chain
      @contracts_chain ||= self.class.ancestors.take_while { |klass| klass != Contr::Base }.reverse
    end
  end

  Act = Base
end
