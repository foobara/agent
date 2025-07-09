require_relative "determine_base"

module Foobara
  class Agent < CommandConnector
    class DetermineNextCommandNameAndInputs < DetermineBase
      class << self
        def llm_instructions(assistant_association_depth, goal)
          key = [assistant_association_depth, goal]

          @llm_instructions_cache ||= {}

          if @llm_instructions_cache.key?(key)
            @llm_instructions_cache[key]
          else
            @llm_instructions_cache[key] = build_llm_instructions(assistant_association_depth, goal)
          end
        end

        def build_llm_instructions(assistant_association_depth, goal)
          instructions = "You are the implementation of a command called #{scoped_full_name}"

          instructions += if description && !description.empty?
                            " which has the following description:\n\n#{description}\n\n"
                          else
                            # :nocov:
                            ". "
                            # :nocov:
                          end

          result_schema = result_json_schema(assistant_association_depth)

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
        self.llm_instructions = self.class.llm_instructions(computed_user_association_depth, goal)
      end
    end
  end
end
