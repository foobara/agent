require "foobara/llm_backed_command"

module Foobara
  class Agent < CommandConnector
    class DetermineNextCommandNameAndInputs < Foobara::LlmBackedCommand
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
          instructions = "You are part of an agent implementation. " \
                         "Your task is to decide which command to run next.\n\n"

          result_schema = result_json_schema(assistant_association_depth)

          if previous_goals && !previous_goals.empty?
            instructions += "You have previously accomplished the following goals:\n\n"

            previous_goals.each.with_index do |(previous_goal, state), index|
              instructions += "previous goal #{index + 1}: #{previous_goal}\n"
              instructions += "status of goal #{index + 1}: #{state}\n\n"
            end
          end

          instructions += "You are working towards accomplishing the following goal: #{goal}\n\n"

          instructions += "You will answer with the name of the next command to run and, if needed, its inputs. " \
                          "Choose whichever command is best to make progress towards accomplishing the current goal " \
                          "based on the progress made so far. " \
                          "If the goal has been accomplished then choose the " \
                          "NotifyUserThatCurrentGoalHasBeenAccomplished command. " \
                          "If you are stuck either due to errors " \
                          "or because you do not have the command you need to accomplish the " \
                          "goal, then choose GiveUp.\n\n"

          instructions += "You can get more details about the inputs and result schemas for a specific command by " \
                          "choosing the DescribeCommand command.\n\n"

          instructions += "Your result type is described by the following JSON schema:" \
                          "\n\n#{result_schema}\n\n" \
                          "You will reply with nothing more than the JSON that you've " \
                          "generated that adheres to this result type schema " \
                          "so that the calling code " \
                          "can successfully parse your answer."

          instructions
        end
      end

      description "Returns the name of the next command to run and its inputs given the progress  " \
                  "towards accomplishing the current goal. " \
                  "If the goal has been accomplished it will choose the " \
                  "NotifyUserThatCurrentGoalHasBeenAccomplished command. It will choose GiveUp if it runs into an " \
                  "error it cannot get around or does not believe it has the proper commands to accomplish its goal."

      result do
        command :string, :required
        inputs :attributes, :allow_nil
      end

      inputs do
        agent Agent, :required
        pass_aggregates_to_llm :boolean, :allow_nil, "Should we send aggregates to the LLM or " \
                                                     "require it to fetch what it needs?"
        llm_model :string,
                  one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                  default: Ai.default_llm_model,
                  description: "The model to use for the LLM"
      end

      def determine_llm_instructions
        self.llm_instructions = self.class.llm_instructions(
          computed_user_association_depth,
          goal,
          previous_goal_and_status_pairs
        )
      end

      def association_depth
        if pass_aggregates_to_llm
          Foobara::AssociationDepth::AGGREGATE
        else
          Foobara::AssociationDepth::ATOM
        end
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

      def goal
        context.current_goal.text
      end

      def previous_goal_and_status_pairs
        if context.previous_goals && !context.previous_goals.empty?
          context.previous_goals.map do |previous_goal|
            [previous_goal.text, previous_goal.state]
          end
        end
      end

      def context
        agent.context
      end
    end
  end
end
