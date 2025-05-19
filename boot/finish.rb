first = [
  "remote.rb"
]

last = [
  "async.rb",
  "cron.rb"
]

skip = ["start.rb", "finish.rb", *first, *last]

first.each { |f| require_relative f if File.exist?("#{__dir__}/#{f}") }

require "foobara/agent"

Dir.entries(__dir__).each do |boot_file|
  next unless boot_file.end_with?(".rb")
  next if skip.include?(boot_file)
  next unless File.exist?("#{__dir__}/#{boot_file}")

  require_relative boot_file
end

last.each { |f| require_relative f if File.exist?("#{__dir__}/#{f}") }
