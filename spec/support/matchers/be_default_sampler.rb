# frozen_string_literal: true

RSpec::Matchers.define :be_default_sampler do
  match do |actual|
    actual.instance_of?(Contr::Sampler::Default)
  end
end
