# frozen_string_literal: true

RSpec::Matchers.define :be_default_logger do
  match do |actual|
    actual.instance_of?(Contr::Logger::Default)
  end
end
