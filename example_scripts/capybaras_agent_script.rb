#!/usr/bin/env ruby

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("./Gemfile", __dir__)
require "bundler/setup"

# add your keys/urls to .env or set them some other way and delete these two lines
require "foobara/load_dotenv"
Foobara::LoadDotenv.run!(dir: __dir__)

require "foobara/anthropic_api" if ENV.key?("ANTHROPIC_API_KEY")
require "foobara/open_ai_api" if ENV.key?("OPENAI_API_KEY")
require "foobara/ollama_api" if ENV.key?("OLLAMA_API_URL")

require_relative "capybaras"
require "foobara/agent"

# works:
llm_model = "claude-3-7-sonnet-20250219"
# llm_model = "qwen3-coder:30b"
# llm_model = "qwen3:30b"
# llm_model = "qwen3:32b"
# llm_model = "qwen3:14b"
# llm_model = "qwen3:8b"
# llm_model = "o1"
# llm_model = "o3"

# does not work:
# llm_model = "gpt-4o"
# llm_model = "qwen3:1.7b"
# llm_model = "qwen3:4b"

capy_agent = Foobara::Agent.new(
  agent_name: "CapyAgent",
  command_classes: [FindAllCapybaras, UpdateCapybara],
  llm_model:,
  verbose: true
)

goal = "There is a capybara with a bad year of birth. Can you find and fix the bad record? Thanks!"
puts "To agent: #{goal}"
outcome = capy_agent.accomplish_goal(goal)

if outcome.success?
  puts "From agent: #{outcome.result[:message_to_user]}"
  puts
else
  puts outcome.errors_sentence
  puts
  exit 1
end

goal = "Thank you so much! Can you set it back so that I can do the demo over again? Thanks!"
puts "To agent: #{goal}"
outcome = capy_agent.accomplish_goal(goal)

if outcome.success?
  puts "From agent: #{outcome.result[:message_to_user]}"
  puts
else
  puts outcome.errors_sentence
  puts
  exit 1
end
