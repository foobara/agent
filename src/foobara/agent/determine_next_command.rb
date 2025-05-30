require "foobara/llm_backed_command"

module Foobara
  class Agent
    class DetermineNextCommand < Foobara::LlmBackedCommand
      extend Concerns::SubclassCacheable

      class << self
        # Allows us to give a more meaningful result type
        def for(command_class_names:, agent_id:)
          cached_subclass(agent_id) do
            command_name = "Foobara::Agent::#{agent_id}::DetermineNextCommand"
            klass = Util.make_class_p(command_name, self)

            klass.description "Accepts the current goal, which might already be accomplished, " \
                              "and context of the work  " \
                              "so far and returns the name of " \
                              "the next command to run to make progress towards " \
                              "accomplishing the goal. If the goal has already been accomplished then choose the " \
                              "NotifyUserThatCurrentGoalHasBeenAccomplished command."

            klass.inputs do
              goal :string, :required, "The current goal to accomplish. If the goal has already been accomplished " \
                                       "by the previous command runs then choose " \
                                       "NotifyUserThatCurrentGoalHasBeenAccomplished to stop the loop."
              context Context, :required, "Context of progress so far"
              llm_model :string,
                        one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                        default: "claude-3-7-sonnet-20250219",
                        description: "The model to use for the LLM"
            end

            klass.result :string,
                         one_of: command_class_names,
                         description: "Name of the next command to run to make progress " \
                                      "towards accomplishing the mission"

            klass
          end
        end
      end

      description "Accepts a goal and context of the work so far and returns the name of the next command to run to " \
                  "make progress towards accomplishing the mission."
    end
  end
end
