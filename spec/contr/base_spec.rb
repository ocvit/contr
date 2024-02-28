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
        expect(contract.logger).to be_an_instance_of Contr::Logger::Default
        expect(contract.sampler).to be_an_instance_of Contr::Sampler::Default
        expect(contract.name).to eq "ContractWithoutRules"
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

        expect(contract.logger).to be_an_instance_of Contr::Logger::Default
        expect(contract.sampler).to be_an_instance_of Contr::Sampler::Default
        expect(contract.name).to eq "ContractWithRules"
      end
    end

    context "contract with custom logger and sampler" do
      before do
        define_class("CustomLogger", Contr::Logger::Base)
        define_class("TweakedCustomLogger", CustomLogger)

        define_class("CustomSampler", Contr::Sampler::Base)
        define_class("TweakedCustomSampler", CustomSampler)
      end

      context "when set via contract definition" do
        before do
          define_contract_class("ContractWithCustomLoggerAndSampler") do
            logger TweakedCustomLogger.new
            sampler TweakedCustomSampler.new
          end
        end

        subject(:contract) { ContractWithCustomLoggerAndSampler.new }

        it "has correct attributes" do
          expect(contract.logger).to be_an_instance_of TweakedCustomLogger
          expect(contract.sampler).to be_an_instance_of TweakedCustomSampler
        end
      end

      context "when set via instance opts" do
        before do
          define_contract_class("ContractWithCustomLoggerAndSamplerFromOpts")
        end

        subject(:contract) do
          ContractWithCustomLoggerAndSamplerFromOpts.new(
            logger: TweakedCustomLogger.new,
            sampler: TweakedCustomSampler.new
          )
        end

        it "has correct attributes" do
          expect(contract.logger).to be_an_instance_of TweakedCustomLogger
          expect(contract.sampler).to be_an_instance_of TweakedCustomSampler
        end
      end
    end

    context "contract with invalid logger" do
      before do
        define_class("InvalidLogger", Object)

        define_contract_class("ContractWithInvalidLogger") do
          logger InvalidLogger.new
        end
      end

      subject(:contract) { ContractWithInvalidLogger.new }

      it "raises validation error" do
        expect { contract }.to raise_error(
          ArgumentError,
          /logger should be inherited from Contr::Logger::Base or be falsey, received:.*InvalidLogger/
        )
      end
    end

    context "contract with invalid sampler" do
      before do
        define_class("InvalidSampler", Object)

        define_contract_class("ContractWithInvalidSampler") do
          sampler InvalidSampler.new
        end
      end

      subject(:contract) { ContractWithInvalidSampler.new }

      it "raises validation error" do
        expect { contract }.to raise_error(
          ArgumentError,
          /\Asampler should be inherited from Contr::Sampler::Base or be falsey, received:.+InvalidSampler.+\z/
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
        expect(contract.sampler).to eq false
      end
    end

    context "contract inherited multiple times" do
      before do
        define_class("CustomLogger", Contr::Logger::Base)
        define_class("CustomSampler", Contr::Sampler::Base)

        define_contract_class("ContractWithCustomLogger") do
          logger CustomLogger.new
          sampler nil

          guarantee(:g1) {}
          guarantee(:g2) {}
          expect(:e1)    {}
        end

        define_contract_class("ContractWithCustomSampler", ContractWithCustomLogger) do
          logger nil
          sampler CustomSampler.new

          guarantee(:g3) {}
          expect(:e2)    {}
        end

        define_contract_class("DeeplyInheritedContract", ContractWithCustomSampler)
        define_contract_class("AnotherDeeplyInheritedContract", DeeplyInheritedContract)
      end

      subject(:contract) { AnotherDeeplyInheritedContract.new }

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
      end
    end
  end

  describe "#check" do
    before :all do
      Timecop.freeze(Time.utc(1999))
      @dump_folder = "/tmp/contract_tests/#{SecureRandom.uuid}"
      @dump_period_id = "1525248"
    end

    after :all do
      Timecop.return
    end

    after do
      FileUtils.rm_rf(@dump_folder)
    end

    before do
      # fixes visibility in block passed to `define_contract_class`
      dump_folder = @dump_folder

      define_contract_class("BaseContract") do
        logger Contr::Logger::Default.new(stream: IO::NULL)
        sampler Contr::Sampler::Default.new(folder: dump_folder)
      end
    end

    let(:contract)         { Object.const_get(contract_name).new }
    let(:operation)        { proc { 1 + 1 } }
    let(:operation_result) { 2 }
    let(:args)             { [1, 2, 3] }

    subject(:result) { contract.check(*args) { operation.call } }

    let(:dump_info) { {path: "#{@dump_folder}/#{contract_name}/#{@dump_period_id}.dump"} }
    let(:log_state) { state.merge(dump_info: dump_info) }

    context "when contract successfully matched" do
      context "without unexpected errors in rules" do
        context "with both guarantees and expectations" do
          before do
            define_contract_class(contract_name, BaseContract) do
              guarantee(:g1) { true }
              guarantee(:g2) { true }
              expect(:e1)    { false }
              expect(:e2)    { true }
            end
          end

          let(:contract_name) { "OkContractNoUnexpectedErrors" }

          it "returns operation result, does not sample, does not log" do
            not_expect_sample
            not_expect_log

            expect(result).to eq operation_result
          end
        end

        context "with guarantees only" do
          before do
            define_contract_class(contract_name, BaseContract) do
              guarantee(:g1) { true }
              guarantee(:g2) { true }
            end
          end

          let(:contract_name) { "OkContractGuaranteesOnly" }

          it "returns operation result, does not sample, does not log" do
            not_expect_sample
            not_expect_log

            expect(result).to eq operation_result
          end
        end

        context "with expectations only" do
          before do
            define_contract_class(contract_name, BaseContract) do
              expect(:e1) { false }
              expect(:e2) { true }
            end
          end

          let(:contract_name) { "OkContractExpectationsOnly" }

          it "returns operation result, does not sample, does not log" do
            not_expect_sample
            not_expect_log

            expect(result).to eq operation_result
          end
        end
      end

      context "with unexpected error in some of the expectations" do
        before do
          define_contract_class(contract_name, BaseContract) do
            guarantee(:g1) { true }
            guarantee(:g2) { true }
            expect(:e1)    { raise StandardError, "some error" }
            expect(:e2)    { true }
          end
        end

        let(:contract_name) { "OkContractUnexpectedErrorInExpectation" }

        it "returns operation result, does not sample, does not log" do
          not_expect_sample
          not_expect_log

          expect(result).to eq operation_result
        end
      end
    end

    context "when contract failed" do
      context "when guarantees failed" do
        before do
          define_contract_class(contract_name, BaseContract) do
            guarantee(:g1) { true }
            guarantee(:g2) { false }
            expect(:e1)    { raise StandardError, "some error" }
            expect(:e2)    { false }
          end
        end

        let(:contract_name) { "FailedContractGuaranteesNotMatched" }
        let(:state) do
          {
            ts:            "1999-01-01T00:00:00.000Z",
            contract_name: contract_name,
            failed_rules:  [{type: :guarantee, name: :g2, status: :failed}],
            ok_rules:      [{type: :guarantee, name: :g1, status: :ok}],
            async:         false,
            args:          [1, 2, 3],
            result:        operation_result
          }
        end

        it "creates sample, writes to log and raises an error" do
          expect_sample_with(state)
          expect_log_with(log_state)

          expect { result }.to raise_error(
            Contr::Matcher::GuaranteesNotMatched,
            "failed rules: [[:guarantee, :g2, :failed]], args: [1, 2, 3]"
          )
        end
      end

      context "when expectations failed" do
        before do
          define_contract_class(contract_name, BaseContract) do
            guarantee(:g1) { true }
            guarantee(:g2) { true }
            expect(:e1)    { raise StandardError, "some error" }
            expect(:e2)    { false }
            expect(:e3)    { false }
          end
        end

        let(:contract_name) { "FailedContractExpectationsNotMatched" }
        let(:state) do
          {
            ts:            "1999-01-01T00:00:00.000Z",
            contract_name: contract_name,
            failed_rules: [
              {type: :expectation, name: :e1, status: :unexpected_error, error: be_a(StandardError)},
              {type: :expectation, name: :e2, status: :failed},
              {type: :expectation, name: :e3, status: :failed}
            ],
            ok_rules: [
              {type: :guarantee, name: :g1, status: :ok},
              {type: :guarantee, name: :g2, status: :ok}
            ],
            async:  false,
            args:   [1, 2, 3],
            result: operation_result
          }
        end

        it "creates sample, writes to log and raises an error" do
          expect_sample_with(state)
          expect_log_with(log_state)

          expect { result }.to raise_error(
            Contr::Matcher::ExpectationsNotMatched,
            "failed rules: [[:expectation, :e1, :unexpected_error, #<StandardError: some error>], [:expectation, :e2, :failed], [:expectation, :e3, :failed]], args: [1, 2, 3]"
          )
        end
      end

      context "when sampler and logger are disabled" do
        before do
          define_contract_class(contract_name, BaseContract) do
            logger nil
            sampler nil

            guarantee(:g1) { false }
          end
        end

        let(:contract_name) { "FailedContractSamplerAndLoggerDisabled" }

        it "raises an error, does not sample, does not log" do
          not_expect_sample
          not_expect_log

          expect { result }.to raise_error(
            Contr::Matcher::GuaranteesNotMatched,
            "failed rules: [[:guarantee, :g1, :failed]], args: [1, 2, 3]"
          )
        end
      end

      context "when sample already exists" do
        before do
          define_contract_class(contract_name, BaseContract) do
            guarantee(:g1) { false }
          end

          create_empty_file(dump_info[:path])
        end

        let(:contract_name) { "FailedContractSampleExists" }
        let(:state) do
          {
            ts:            "1999-01-01T00:00:00.000Z",
            contract_name: contract_name,
            failed_rules:  [{type: :guarantee, name: :g1, status: :failed}],
            ok_rules:      [],
            async:         false,
            args:          [1, 2, 3],
            result:        operation_result
          }
        end

        it "does not create new sample, logs original state and raises an error" do
          expect_sample_with(state)
          expect_log_with(state)

          expect { result }.to raise_error(
            Contr::Matcher::GuaranteesNotMatched,
            "failed rules: [[:guarantee, :g1, :failed]], args: [1, 2, 3]"
          )
        end
      end
    end

    context "alternative ways of handling args" do
      before do
        define_contract_class(contract_name, BaseContract) do
          guarantee(:g1) { true }
          guarantee(:g2) { |arg_1, _| arg_1 == 1 }
          guarantee(:g3) { |_, arg_2| arg_2 == 2 }
          guarantee(:g4) { @args == [1, 2] }
          guarantee(:g5) { @result == 2 }
          guarantee(:g6) { @contract.is_a?(ContractWithAllPossibleArgs) }
          guarantee(:g7) { @guarantees.size == 8 && @expectations.size == 1 }
          guarantee(:g8) { @logger.is_a?(Contr::Logger::Default) }
          expect(:e1)    { @sampler.is_a?(Contr::Sampler::Default) }
        end
      end

      let(:contract_name) { "ContractWithAllPossibleArgs" }
      let(:args) { [1, 2] }

      it "makes args available for all the rules" do
        expect(result).to eq operation_result
      end
    end

    context "when checked operation raises an error" do
      let(:contract_name) { "BaseContract" }
      let(:operation) { proc { raise StandardError, "some error" } }

      it "raises an error right away, does not sample, does not log" do
        not_expect_sample
        not_expect_log

        expect { result }.to raise_error(StandardError, "some error")
      end
    end
  end

  def expect_log_with(*args)
    expect(contract.logger).to receive(:log).with(*args).once.and_call_original
  end

  def expect_sample_with(*args)
    expect(contract.sampler).to receive(:sample!).with(*args).once.and_call_original
  end

  def not_expect_log
    expect(contract.logger).to_not receive(:log)
  end

  def not_expect_sample
    expect(contract.sampler).to_not receive(:sample!)
  end
end

RSpec.describe Contr::Act do
  it "is an alias to Base" do
    expect(Contr::Act).to eq Contr::Base
  end
end
