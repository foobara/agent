require "foobara/llm_backed_command"

module Foobara
  class Agent < CommandConnector
    class DetermineNextCommandNameAndInputs < Foobara::LlmBackedCommand
      description "Accepts the current goal, which might already be accomplished, and context of the work  " \
                  "so far and returns the inputs for " \
                  "the next command to run to make progress towards " \
                  "accomplishing the goal. If the goal has already been accomplished then choose the " \
                  "NotifyUserThatCurrentGoalHasBeenAccomplished command."

      inputs do
        goal :string, :required, "The current goal to accomplish. If the goal has already been accomplished " \
                                 "by the previous command runs then choose " \
                                 "NotifyUserThatCurrentGoalHasBeenAccomplished to stop the loop."
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
