# frozen_string_literal: true

RSpec.describe Contr::Async::Pool::Fixed do
  subject(:pool) { described_class.new }

  it "has correct attributes" do
    expect(pool).to be_fixed_async_pool
  end
end
