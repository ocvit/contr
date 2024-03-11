# frozen_string_literal: true

# load gem from source
# $: << File.expand_path("../../lib", __FILE__)

require "contr"

class SumContract < Contr::Act
  guarantee :result_is_float do |(_), result|
    result.is_a?(Float)
  end

  guarantee :result_is_positive do |(_), result|
    result > 0
  end

  guarantee :args_are_numbers do |args|
    args.all?(Numeric)
  end

  expect :arg_1_is_float do |(arg_1, _)|
    arg_1.is_a?(Float)
  end

  expect :arg_2_is_float do |(_, arg_2)|
    arg_2.is_a?(Float)
  end
end

args = [1, 2.0]
contract = SumContract.new

contract.check(*args) { args.inject(:+) }
# => 3.0

contract.check_async(*args) { args.inject(:+) }
# => 3.0
# (no state dump, no log)
