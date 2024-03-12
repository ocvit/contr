# frozen_string_literal: true

require "securerandom"
require "timecop"

RSpec.describe Contr::Base do
  include ClassHelpers
  include FileHelpers

  describe ".new" do
    context "contract without rules" do
      before do
        define_contract_class("ContractWithoutRules")
      end

      subject(:contract) { ContractWithoutRules.new }

      it "has correct attributes" do
        expect(contract.guarantees).to eq []
        expect(contract.expectations).to eq []
        expect(contract.logger).to be_default_logger
        expect(contract.sampler).to be_default_sampler
        expect(contract.main_pool).to be_fixed_async_pool
        expect(contract.rules_pool).to be_nil
        expect(contract.name).to eq "ContractWithoutRules"
        expect(contract.frozen?).to eq true
      end
    end

    context "contract with rules" do
      before do
        define_contract_class("ContractWithRules") do
          guarantee(:g1) {}
          guarantee(:g2) {}
          expect(:e1)    {}
          expect(:e2)    {}
        end
      end

      subject(:contract) { ContractWithRules.new }

      it "has correct attributes" do
        expect(contract.guarantees).to match([
          {type: :guarantee, name: :g1, block: be_a(Proc)},
          {type: :guarantee, name: :g2, block: be_a(Proc)}
        ])

        expect(contract.expectations).to match([
          {type: :expectation, name: :e1, block: be_a(Proc)},
          {type: :expectation, name: :e2, block: be_a(Proc)}
        ])
      end
    end

    context "contract with custom config" do
      before do
        define_class("CustomLogger", Contr::Logger::Base)
        define_class("CustomSampler", Contr::Sampler::Base)
        define_class("CustomRulesPool", Contr::Async::Pool::Base)
      end

      context "when set via contract definition" do
        before do
          define_contract_class("ContractWithCustomConfig") do
            async pools: {rules: CustomRulesPool.new}
            logger CustomLogger.new
            sampler CustomSampler.new
          end
        end

        subject(:contract) { ContractWithCustomConfig.new }

        it "has correct attributes" do
          expect(contract.logger).to be_an_instance_of CustomLogger
          expect(contract.sampler).to be_an_instance_of CustomSampler
          expect(contract.main_pool).to be_fixed_async_pool
          expect(contract.rules_pool).to be_an_instance_of CustomRulesPool
        end
      end

      context "when set via instance opts" do
        before do
          define_contract_class("ContractWithCustomConfigFromOpts")
        end

        subject(:contract) do
          ContractWithCustomConfigFromOpts.new(
            async: {pools: {rules: CustomRulesPool.new}},
            logger: CustomLogger.new,
            sampler: CustomSampler.new
          )
        end

        it "has correct attributes" do
          expect(contract.logger).to be_an_instance_of CustomLogger
          expect(contract.sampler).to be_an_instance_of CustomSampler
          expect(contract.main_pool).to be_fixed_async_pool
          expect(contract.rules_pool).to be_an_instance_of CustomRulesPool
        end
      end
    end

    context "contract with disabled main pool" do
      before do
        define_contract_class("ContractWithDisabledMainPool") do
          async pools: {main: nil}
        end
      end

      subject(:contract) { ContractWithDisabledMainPool.new }

      it "raises validation error" do
        expect { contract }.to raise_error(ArgumentError, "main pool can't be disabled")
      end
    end

    context "contract with invalid main pool" do
      before do
        define_contract_class("ContractWithInvalidMainPoolConfig") do
          async pools: {main: :invalid_value}
        end
      end

      subject(:contract) { ContractWithInvalidMainPoolConfig.new }

      it "raises validation error" do
        expect { contract }.to raise_error(
          ArgumentError,
          "main pool should be inherited from Contr::Async::Pool::Base, received: :invalid_value"
        )
      end
    end

    context "contract with disabled rules pool" do
      before do
        define_contract_class("ContractWithDisabledRulesPool") do
          async pools: {rules: false}
        end
      end

      subject(:contract) { ContractWithDisabledRulesPool.new }

      it "has correct attribute" do
        expect(contract.rules_pool).to be_nil
      end
    end

    context "contract with invalid rules pool" do
      before do
        define_contract_class("ContractWithInvalidRulesPool") do
          async pools: {rules: :invalid_value}
        end
      end

      subject(:contract) { ContractWithInvalidRulesPool.new }

      it "raises validation error" do
        expect { contract }.to raise_error(
          ArgumentError,
          "rules pool should be inherited from Contr::Async::Pool::Base or be falsy, received: :invalid_value"
        )
      end
    end

    context "contract with invalid logger" do
      before do
        define_contract_class("ContractWithInvalidLogger") do
          logger :invalid_value
        end
      end

      subject(:contract) { ContractWithInvalidLogger.new }

      it "raises validation error" do
        expect { contract }.to raise_error(
          ArgumentError,
          "logger should be inherited from Contr::Logger::Base or be falsy, received: :invalid_value"
        )
      end
    end

    context "contract with invalid sampler" do
      before do
        define_contract_class("ContractWithInvalidSampler") do
          sampler :invalid_value
        end
      end

      subject(:contract) { ContractWithInvalidSampler.new }

      it "raises validation error" do
        expect { contract }.to raise_error(
          ArgumentError,
          "sampler should be inherited from Contr::Sampler::Base or be falsy, received: :invalid_value"
        )
      end
    end

    context "contract with disabled logger and sampler" do
      before do
        define_contract_class("ContractWithLoggerAndSamplerDisabled") do
          logger nil
          sampler false
        end
      end

      subject(:contract) { ContractWithLoggerAndSamplerDisabled.new }

      it "has correct attributes" do
        expect(contract.logger).to eq nil
        expect(contract.sampler).to eq nil
      end
    end

    context "contract inherited multiple times" do
      before do
        define_class("CustomLogger", Contr::Logger::Base)
        define_class("CustomSampler", Contr::Sampler::Base)

        define_contract_class("ContractLevel1") do
          async pools: {rules: Contr::Async::Pool::GlobalIO.new}
          logger CustomLogger.new
          sampler nil

          guarantee(:g1) {}
          guarantee(:g2) {}
          expect(:e1)    {}
        end

        define_contract_class("ContractLevel2", ContractLevel1) do
          async pools: {main: Contr::Async::Pool::Fixed.new}
          logger nil
          sampler CustomSampler.new

          guarantee(:g3) {}
          expect(:e2)    {}
        end

        define_contract_class("ContractLevel3", ContractLevel2)
        define_contract_class("ContractLevel4", ContractLevel3)
      end

      subject(:contract) { ContractLevel4.new }

      it "inherits configs from parent contracts" do
        expect(contract.logger).to eq nil
        expect(contract.sampler).to be_an_instance_of CustomSampler
        expect(contract.guarantees).to match [
          {type: :guarantee, name: :g1, block: be_a(Proc)},
          {type: :guarantee, name: :g2, block: be_a(Proc)},
          {type: :guarantee, name: :g3, block: be_a(Proc)}
        ]
        expect(contract.expectations).to match [
          {type: :expectation, name: :e1, block: be_a(Proc)},
          {type: :expectation, name: :e2, block: be_a(Proc)}
        ]
        expect(contract.main_pool).to be_fixed_async_pool
        expect(contract.rules_pool).to be_global_io_async_pool
      end
    end
  end

  describe "#check" do
    include_context "contract check setup"

    before do
      define_contract_class("BaseContract", PreConfiguredContract)
    end

    subject(:result) { contract.check(*args) { operation.call } }

    it_behaves_like "contract check"
    it_behaves_like "contract matched"
    it_behaves_like "contract failed in sync check"
  end

  describe "#check_async" do
    include_context "contract check setup"

    subject(:result) { contract.check_async(*args) { operation.call } }

    context "with async rules" do
      context "using fixed pool" do
        before do
          define_contract_class("BaseContract", PreConfiguredContract) do
            async pools: {rules: Contr::Async::Pool::Fixed.new}
          end

          run_async_matcher_inline!
        end

        it_behaves_like "contract check"
        it_behaves_like "contract matched"
        it_behaves_like "contract failed in async check with async rules"
      end

      context "using global pool" do
        before do
          define_contract_class("BaseContract", PreConfiguredContract) do
            async pools: {rules: Contr::Async::Pool::GlobalIO.new}
          end

          run_async_matcher_inline!
        end

        it_behaves_like "contract check"
        it_behaves_like "contract matched"
        it_behaves_like "contract failed in async check with async rules"
      end
    end

    context "with sync rules" do
      before do
        define_contract_class("BaseContract", PreConfiguredContract) do
          async pools: {rules: nil}
        end

        run_async_matcher_inline!
      end

      it_behaves_like "contract check"
      it_behaves_like "contract matched"
      it_behaves_like "contract failed in async check with sync rules"
    end

    context "when async matcher not inlined" do
      before do
        define_contract_class(contract_name, PreConfiguredContract) do
          expect(:g1) { true }
        end
      end

      let(:contract_name) { "ContractRegularAsyncCheck" }

      it "does not wait for contract future to resolve" do
        expect_any_instance_of(Concurrent::Future).not_to receive(:wait!)

        expect(result).to eq operation_result
      end
    end
  end

  def run_async_matcher_inline!
    allow_any_instance_of(Contr::Matcher::Async).to receive(:inline?).and_return(true)
  end
end

RSpec.describe Contr::Act do
  it "is an alias to Base" do
    expect(Contr::Act).to eq Contr::Base
  end
end
