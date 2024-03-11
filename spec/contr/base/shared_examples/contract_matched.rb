# frozen_string_literal: true

RSpec.shared_examples "contract matched" do
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
