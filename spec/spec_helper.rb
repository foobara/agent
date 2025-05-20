ENV["FOOBARA_ENV"] = "test"

require "bundler/setup"

require "pry"
require "pry-byebug"
require "rspec/its"

require_relative "support/simplecov"
require_relative "../boot/start"

RSpec.configure do |config|
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.order = :defined
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.raise_errors_for_deprecations!
end

Dir["#{__dir__}/support/**/*.rb"].each { |f| require f }

require "foobara/spec_helpers/all"

VCR.use_cassette("list_models", record: :none) do
  require "foobara/anthropic_api"
  require_relative "../boot/finish"
end
# raise "Just rerecording the list_models cassette, no need to proceed"
