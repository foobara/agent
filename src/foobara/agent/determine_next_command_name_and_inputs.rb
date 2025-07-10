require_relative "determine_base"

module Foobara
  class Agent < CommandConnector
    class DetermineNextCommandNameAndInputs < DetermineBase
      class << self
        def llm_instructions(assistant_association_depth, goal, previous_goals = nil)
          key = [assistant_association_depth, goal, previous_goals]

          @llm_instructions_cache ||= {}

          if @llm_instructions_cache.key?(key)
            @llm_instructions_cache[key]
          else
            @llm_instructions_cache[key] = build_llm_instructions(assistant_association_depth, goal, previous_goals)
          end
        end

        def build_llm_instructions(assistant_association_depth, goal, previous_goals)
          instructions = "You are the implementation of a command called #{scoped_full_name}"

          instructions += if description && !description.empty?
                            " which has the following description:\n\n#{description}\n\n"
                          else
                            # :nocov:
                            ". "
                            # :nocov:
                          end

          result_schema = result_json_schema(assistant_association_depth)

          if previous_goals && !previous_goals.empty?
            instructions += "You have previously accomplished the following goals:\n\n"

            previous_goals.each.with_index do |(previous_goal, state), index|
              instructions += "previous goal #{index + 1}: #{previous_goal}\n"
              instructions += "status of goal #{index + 1}: #{state}\n\n"
            end
          end

          instructions += "You are working towards accomplishing the following goal:\n\n#{goal}\n\n"

          instructions += "Your response of which command to run next should match the following JSON schema:"
          instructions += "\n\n#{result_schema}\n\n"
          instructions += "You can get more details about the inputs and result schemas for a specific command by " \
                          "choosing the DescribeCommand command. " \
                          "You will reply with nothing more than the JSON you've generated so that the calling code " \
                          "can successfully parse your answer."

          instructions
        end
      end

      description "Returns the name of the next command to run and its inputs given the progress  " \
                  "towards accomplishing the current goal. " \
                  "If the goal has been accomplished it will choose the " \
                  "NotifyUserThatCurrentGoalHasBeenAccomplished command."

      result do
        command :string, :required
        inputs :attributes, :allow_nil
      end

      def determine_llm_instructions
        self.llm_instructions = self.class.llm_instructions(
          computed_user_association_depth,
          goal,
          previous_goal_and_status_pairs
        )
      end
    end
  end
end
