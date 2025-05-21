require "simplecov"

SimpleCov.start do
  add_filter "spec/support"
  # enable_coverage :branch
  minimum_coverage line: 100
  # TODO: enable this? worth it to get to 100% branch coverage?
  # minimum_coverage line: 100, branch: 100
end
