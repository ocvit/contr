# frozen_string_literal: true

RSpec.describe Contr::Logger do
  include ClassHelpers

  describe described_class::Base do
    context "when logger does not implement `#log`" do
      before do
        define_class("AnotherLogger", described_class)
      end

      subject(:log) { AnotherLogger.new.log({}) }

      it "raises an error" do
        expect { log }.to raise_error(
          NotImplementedError,
          "logger should implement `#log` method"
        )
      end
    end
  end
end
