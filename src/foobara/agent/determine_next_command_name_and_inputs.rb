require "foobara/llm_backed_command"

module Foobara
  class Agent
    class DetermineNextCommandNameAndInputs < Foobara::LlmBackedCommand
      description "Accepts a goal and context of the work so far and returns the inputs for " \
                  "the next command to run to make progress towards " \
                  "accomplishing the goal."

      inputs do
        goal :string, :required, "What do you want the agent to attempt to accomplish?"
        context Context, :required, "Context of the progress towards the goal so far"
        command_class_names [:string], :required
        llm_model :string,
                  one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                  default: "claude-3-7-sonnet-20250219",
                  description: "The model to use for the LLM"
      end

      result do
        command_name :string, :required
        inputs :attributes, :allow_nil
      end
    end
  end
end
