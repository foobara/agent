require "foobara/llm_backed_command"

module Foobara
  class Agent
    class DetermineInputsForNextCommand < Foobara::LlmBackedCommand
      extend Concerns::SubclassCacheable

      class << self
        def for(command_class:, agent_id:)
          cached_subclass([command_class.full_command_name, agent_id]) do
            command_short_name = Util.non_full_name(command_class.command_name)
            class_name = "Foobara::Agent::#{agent_id}::DetermineInputsForNext#{command_short_name}Command"
            klass = Util.make_class_p(class_name, self)

            klass.description "Accepts a goal and context of the work so far and returns the inputs for " \
                              "the next #{command_short_name} command to run to make progress towards " \
                              "accomplishing the goal."

            klass.inputs do
              goal :string, :required, "The current (possibly already accomplished) goal"
              context Context, :required, "Context of the progress towards the goal so far"
              llm_model :string,
                        one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                        default: "claude-3-7-sonnet-20250219",
                        description: "The model to use for the LLM"
            end

            if command_class.inputs_type
              klass.result command_class.inputs_type
            end

            klass
          end
        end
      end
    end
  end
end
