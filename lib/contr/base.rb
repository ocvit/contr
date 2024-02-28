# frozen_string_literal: true

module Contr
  class Base
    class << self
      attr_reader :config, :guarantees, :expectations

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

    attr_reader :logger, :sampler

    def initialize(instance_config = {})
      @logger = choose_logger(instance_config)
      @sampler = choose_sampler(instance_config)

      validate_logger!
      validate_sampler!
    end

    def check(*args)
      result = yield
      Matcher::Sync.new(self, args, result).match
      result
    end

    def name
      self.class.name
    end

    def guarantees
      @guarantees ||= aggregate_rules(:guarantees)
    end

    def expectations
      @expectations ||= aggregate_rules(:expectations)
    end

    private

    def choose_logger(instance_config)
      parent_config = find_parent_config(:logger)

      case [instance_config, self.class.config, parent_config]
      in [{logger: }, *]
        logger
      in [_, {logger: }, _]
        logger
      in [*, {logger: }]
        logger
      else
        Logger::Default.new
      end
    end

    def choose_sampler(instance_config)
      parent_config = find_parent_config(:sampler)

      case [instance_config, self.class.config, parent_config]
      in [{sampler: }, *]
        sampler
      in [_, {sampler: }, _]
        sampler
      in [*, {sampler: }]
        sampler
      else
        Sampler::Default.new
      end
    end

    def find_parent_config(key)
      parents = self.class.ancestors.take_while { |klass| klass != Contr::Base }.drop(1)
      parents.detect { |klass| klass.config&.key?(key) }&.config
    end

    def aggregate_rules(rule_type)
      contracts_chain = self.class.ancestors.take_while { |klass| klass != Contr::Base }.reverse
      contracts_chain.flat_map(&rule_type).compact
    end

    def validate_logger!
      return unless logger
      return if logger.class.ancestors.include?(Logger::Base)

      raise ArgumentError, "logger should be inherited from Contr::Logger::Base or be falsey, received: #{logger.inspect}"
    end

    def validate_sampler!
      return unless sampler
      return if sampler.class.ancestors.include?(Sampler::Base)

      raise ArgumentError, "sampler should be inherited from Contr::Sampler::Base or be falsey, received: #{sampler.inspect}"
    end
  end

  Act = Base
end
