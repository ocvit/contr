# frozen_string_literal: true

RSpec.describe Contr::Matcher do
  include ClassHelpers

  describe described_class::Base do
    context "when matcher does not implement `#match`" do
      before do
        define_class("AnotherMatcher", described_class)
      end

      subject(:match) { AnotherMatcher.new(Contr::Act.new, nil, nil).match }

      it "raises an error" do
        expect { match }.to raise_error(
          NotImplementedError,
          "matcher should implement `#match` method"
        )
      end
    end
  end
end
