# frozen_string_literal: true

RSpec.describe Contr::Async::Pool do
  include ClassHelpers

  describe described_class::Base do
    context "when pool does not implement `#create_executor`" do
      before do
        define_class("AnotherPool", described_class)
      end

      subject(:executor) { AnotherPool.new.executor }

      it "raises an error" do
        expect { executor }.to raise_error(
          NotImplementedError,
          "pool should implement `#create_executor` method"
        )
      end
    end
  end
end
