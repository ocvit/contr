# frozen_string_literal: true

RSpec.describe Contr::Sampler do
  include ClassHelpers

  describe described_class::Base do
    context "when sampler does not implement `#sample!`" do
      before do
        define_class("AnotherSampler", described_class)
      end

      subject(:sample!) { AnotherSampler.new.sample!({}) }

      it "raises an error" do
        expect { sample! }.to raise_error(
          NotImplementedError,
          "sampler should implement `#sample!` method"
        )
      end
    end
  end
end
