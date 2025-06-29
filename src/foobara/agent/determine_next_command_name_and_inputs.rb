require "foobara/llm_backed_command"

module Foobara
  class Agent < CommandConnector
    class DetermineNextCommandNameAndInputs < Foobara::LlmBackedCommand
      description "Returns the name of the next command to run and its inputs given the progress  " \
                  "towards accomplishing the current goal. " \
                  "If the goal has been accomplished it will choose the " \
                  "NotifyUserThatCurrentGoalHasBeenAccomplished command."

      inputs do
        context Context, :required, "Context of the progress towards the goal so far"
        llm_model :string,
                  one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                  default: "claude-3-7-sonnet-20250219",
                  description: "The model to use for the LLM"
      end

      result do
        command_name :string, :required
        inputs :attributes, :allow_nil
      end

      def association_depth
        Foobara::JsonSchemaGenerator::AssociationDepth::ATOM
      end

      def build_messages
        p = [
          {
            content: llm_instructions,
            role: :system
          }
        ]

        context.command_log.each do |command_log_entry|
          agent_entry = {
            command: command_log_entry.command_name
          }

          inputs = command_log_entry.inputs

          if inputs && !inputs.empty?
            agent_entry[:inputs] = inputs
          end

          outcome_entry = command_log_entry.outcome

          p << {
            content: agent_entry,
            role: :assistant
          }
          p << {
            content: outcome_entry,
            role: :user
          }
        end

        p
      end

      def llm_instructions
        return @llm_instructions if defined?(@llm_instructions)

        description = self.class.description

        instructions = "You are the implementation of a command called #{self.class.scoped_full_name}"

        instructions += if description && !description.empty?
                          " which has the following description:\n\n#{self.class.description}\n\n"
                        else
                          # :nocov:
                          ". "
                          # :nocov:
                        end

        instructions += "You are working towards accomplishing the following goal:\n\n#{goal}\n\n"
        instructions +=
          "You are expected to respond with the next command and inputs to run to accomplish this goal.\n\n"
        instructions += "Your response should match the following JSON schema: \n\n#{self.class.result_json_schema}\n\n"
        instructions += "You can get more details about the result schema for a specific command by " \
                        "choosing the DescribeCommand command. " \
                        "You will reply with nothing more than the JSON you've generated so that the calling code " \
                        "can successfully parse your answer."

        @llm_instructions = instructions
      end

      def goal
        context.current_goal
      end
    end
  end
end
