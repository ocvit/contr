# frozen_string_literal: true

require "simplecov"

SimpleCov.start do
  enable_coverage :branch

  add_filter "/spec/"
end

require "simplecov-lcov"

SimpleCov::Formatter::LcovFormatter.config do |config|
  config.report_with_single_file = true
  config.single_report_path = "coverage/lcov.info"
end

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter
])

require "contr"

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = "tmp/rspec_status.txt"

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  # disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!
end
