# frozen_string_literal: true

require_relative "lib/contr/version"

Gem::Specification.new do |spec|
  spec.name = "contr"
  spec.version = Contr::VERSION
  spec.authors = ["Dmytro Horoshko"]
  spec.email = ["electric.molfar@gmail.com"]

  spec.summary = "Minimalistic contracts in plain Ruby"
  spec.description = "Minimalistic contracts in plain Ruby."
  spec.homepage = "https://github.com/ocvit/contr"
  spec.license = "MIT"
  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/ocvit/contr/issues",
    "changelog_uri" => "https://github.com/ocvit/contr/blob/main/CHANGELOG.md",
    "homepage_uri" => "https://github.com/ocvit/contr",
    "source_code_uri" => "https://github.com/ocvit/contr"
  }

  spec.files = Dir.glob("lib/**/*") + %w[README.md CHANGELOG.md LICENSE.txt]
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.7"
end
