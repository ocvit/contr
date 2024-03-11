# frozen_string_literal: true

RSpec.shared_examples "contract failed in sync check" do
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
