require_relative "version"

Gem::Specification.new do |spec|
  spec.name = "foobara-agent"
  spec.version = Foobara::AgentVersion::VERSION
  spec.authors = ["Miles Georgi"]
  spec.email = ["azimux@gmail.com"]

  spec.summary = "An agent that uses Foobara commands to get its job done"
  spec.homepage = "https://github.com/foobara/agent"
  spec.license = "MPL-2.0"
  spec.required_ruby_version = Foobara::AgentVersion::MINIMUM_RUBY_VERSION

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "src/**/*",
    "LICENSE*.txt",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.add_dependency "foobara", "~> 0.0.125"
  spec.add_dependency "foobara-llm-backed-command", "~> 0.0.1"

  spec.require_paths = ["lib"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
