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

llm_model = "claude-3-7-sonnet-20250219"
# llm_model = "qwen3-coder:30b"
# llm_model = "o3"

capy_agent = Foobara::Agent.new(
  agent_name: "CapyAgent",
  command_classes: [FindAllCapybaras, UpdateCapybara],
  llm_model:,
  result_type: Capybara,
  verbose: true
)

def handle_outcome(outcome)
  puts
  if outcome.success?
    capy = outcome.result[:result_data]
    puts "Agent returned #{capy.name} who now has a year_of_birth of #{capy.year_of_birth}"
    puts "Message from agent: #{outcome.result[:message_to_user]}"
    puts
  else
    puts outcome.errors_sentence
    puts
    exit 1
  end
end

goal = "There is a capybara with a bad year of birth. Can you find and fix the bad record? Thanks!"
puts "To agent: #{goal}"
outcome = capy_agent.accomplish_goal(goal)
handle_outcome(outcome)

goal = "Thank you so much! Can you set it back so that I can do the demo over again? Thanks!"
puts "To agent: #{goal}"
outcome = capy_agent.accomplish_goal(goal)
handle_outcome(outcome)
