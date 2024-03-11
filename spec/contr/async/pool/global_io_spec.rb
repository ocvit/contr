# frozen_string_literal: true

RSpec.describe Contr::Async::Pool::GlobalIO do
  subject(:pool) { described_class.new }

  it "has correct attributes" do
    expect(pool).to be_global_io_async_pool
  end
end
