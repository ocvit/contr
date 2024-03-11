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
    args.all? { |arg| arg.is_a?(Numeric) }
  end

  expect :arg_1_is_float do |(arg_1, _)|
    arg_1.is_a?(Float)
  end

  expect :arg_2_is_integer do |(_, arg_2)|
    arg_2.is_a?(Integer)
  end
end

args = [1, 2.0]
contract = SumContract.new

contract.check(*args) { args.inject(:+) }
# => Contr::Matcher::ExpectationsNotMatched: failed rules: [[:expectation, :arg_1_is_float, :failed], [:expectation, :arg_2_is_integer, :failed]], args: [1, 2.0]

# [if previous dump doesn't exist]
#
# state dumped to: /tmp/contracts/SumContract/2850248.dump
# state:
# {
#   ts:            "2024-03-11T09:23:04.245Z",
#   contract_name: "SumContract",
#   failed_rules: [
#     {type: :expectation, name: :arg_1_is_float, status: :failed},
#     {type: :expectation, name: :arg_2_is_integer, status: :failed}
#   ],
#   ok_rules: [
#     {type: :guarantee, name: :result_is_float, status: :ok},
#     {type: :guarantee, name: :result_is_positive, status: :ok},
#     {type: :guarantee, name: :args_are_numbers, status: :ok}
#   ],
#   async:  false,
#   args:   [1, 2.0],
#   result: 3.0
# }
#
# log:
# D, [2024-03-11T11:23:04.245811 #71262] DEBUG -- : {"ts":"2024-03-11T09:23:04.245Z","contract_name":"SumContract","failed_rules":[{"type":"expectation","name":"arg_1_is_float","status":"failed"},{"type":"expectation","name":"arg_2_is_integer","status":"failed"}],"ok_rules":[{"type":"guarantee","name":"result_is_float","status":"ok"},{"type":"guarantee","name":"result_is_positive","status":"ok"},{"type":"guarantee","name":"args_are_numbers","status":"ok"}],"async":false,"args":[1,2.0],"result":3.0,"dump_info":{"path":"/tmp/contracts/SumContract/2850248.dump"},"tag":"contract-failed"}

# [if previous dump exists]
#
# state is not dumped once again (10 minutes window by default), but still logged - without `dump_info` field this time
#
# log:
# D, [2024-03-11T11:23:04.245811 #71262] DEBUG -- : {"ts":"2024-03-11T09:23:04.245Z","contract_name":"SumContract","failed_rules":[{"type":"expectation","name":"arg_1_is_float","status":"failed"},{"type":"expectation","name":"arg_2_is_integer","status":"failed"}],"ok_rules":[{"type":"guarantee","name":"result_is_float","status":"ok"},{"type":"guarantee","name":"result_is_positive","status":"ok"},{"type":"guarantee","name":"args_are_numbers","status":"ok"}],"async":false,"args":[1,2.0],"result":3.0,"tag":"contract-failed"}

contract.check_async(*args) { args.inject(:+) }
# => 3.0

# [if previous dump doesn't exist]
#
# state dumped to: /tmp/contracts/SumContract/2850248.dump
# state:
# {
#   ts:            "2024-03-11T09:23:04.245Z",
#   contract_name: "SumContract",
#   failed_rules: [
#     {type: :expectation, name: :arg_1_is_float, status: :failed},
#     {type: :expectation, name: :arg_2_is_integer, status: :failed}
#   ],
#   ok_rules: [
#     {type: :guarantee, name: :result_is_float, status: :ok},
#     {type: :guarantee, name: :result_is_positive, status: :ok},
#     {type: :guarantee, name: :args_are_numbers, status: :ok}
#   ],
#   async:  true,
#   args:   [1, 2.0],
#   result: 3.0
# }
#
# log:
# D, [2024-03-11T11:23:04.245811 #71262] DEBUG -- : {"ts":"2024-03-11T09:23:04.245Z","contract_name":"SumContract","failed_rules":[{"type":"expectation","name":"arg_1_is_float","status":"failed"},{"type":"expectation","name":"arg_2_is_integer","status":"failed"}],"ok_rules":[{"type":"guarantee","name":"result_is_float","status":"ok"},{"type":"guarantee","name":"result_is_positive","status":"ok"},{"type":"guarantee","name":"args_are_numbers","status":"ok"}],"async":true,"args":[1,2.0],"result":3.0,"dump_info":{"path":"/tmp/contracts/SumContract/2850248.dump"},"tag":"contract-failed"}

# [if previous dump exists]
#
# state is not dumped once again (10 minutes window by default), but still logged - without `dump_info` field this time
#
# log:
# D, [2024-03-11T11:23:04.245811 #71262] DEBUG -- : {"ts":"2024-03-11T09:23:04.245Z","contract_name":"SumContract","failed_rules":[{"type":"expectation","name":"arg_1_is_float","status":"failed"},{"type":"expectation","name":"arg_2_is_integer","status":"failed"}],"ok_rules":[{"type":"guarantee","name":"result_is_float","status":"ok"},{"type":"guarantee","name":"result_is_positive","status":"ok"},{"type":"guarantee","name":"args_are_numbers","status":"ok"}],"async":true,"args":[1,2.0],"result":3.0,"tag":"contract-failed"}
