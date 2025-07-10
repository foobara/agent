require "foobara/llm_backed_command"

module Foobara
  class Agent < CommandConnector
    # TODO: just move this back to DetermineNextCommandAndInputs since it's now the only base class
    class DetermineBase < Foobara::LlmBackedCommand
      inputs do
        pass_aggregates_to_llm :boolean, :allow_nil, "Should we send aggregates to the LLM or " \
                                                     "require it to fetch what it needs?"
        agent Agent, :required
        llm_model :string,
                  one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                  default: Ai.default_llm_model,
                  description: "The model to use for the LLM"
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
