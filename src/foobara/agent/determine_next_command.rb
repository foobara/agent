require "foobara/llm_backed_command"

module Foobara
  class Agent < CommandConnector
    class DetermineNextCommand < Foobara::LlmBackedCommand
      description "Accepts the current goal, which might already be accomplished, " \
                  "and context of the work  " \
                  "so far and returns the name of " \
                  "the next command to run to make progress towards " \
                  "accomplishing the goal. If the goal has already been accomplished then choose the " \
                  "NotifyUserThatCurrentGoalHasBeenAccomplished command."

      inputs do
        goal :string, :required, "The current goal to accomplish. If the goal has already been accomplished " \
                                 "by the previous command runs then choose " \
                                 "NotifyUserThatCurrentGoalHasBeenAccomplished to stop the loop."
        context Context, :required, "Context of progress so far"
        llm_model :string,
                  one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                  default: "claude-3-7-sonnet-20250219",
                  description: "The model to use for the LLM"
      end

      result :string,
             description: "Name of the next command to run to make progress " \
                          "towards accomplishing the mission"
      def association_depth
        Foobara::JsonSchemaGenerator::AssociationDepth::ATOM
      end
    end
  end
end
