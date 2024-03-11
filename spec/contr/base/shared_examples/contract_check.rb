# frozen_string_literal: true

RSpec.shared_examples "contract check" do
  context "different ways of handling args in rules" do
    before do
      define_contract_class(contract_name, BaseContract) do
        guarantee(:g1) { true }
        guarantee(:g2) { |(arg_0, _)| arg_0 == 0 }
        guarantee(:g3) { |(arg_0, *)| arg_0 == 0 }
        guarantee(:g4) { |(_, arg_1)| arg_1 == 1 }
        guarantee(:g5) { |(*, arg_1)| arg_1 == 1 }
        guarantee(:g6) { |(_), result| result == 2 }
        guarantee(:g7) { |(arg_0, arg_1), _| arg_0 == 0 && arg_1 == 1 }
        guarantee(:g8) { |args, result| args == [0, 1] && result == 2 }
        expect(:e1)    { |(arg_0, arg_1), result| arg_0 == 0 && arg_1 == 1 && result == 2 }
      end
    end

    let(:contract_name) { "ContractWithAllPossibleArgs" }
    let(:args)          { [0, 1] }

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
