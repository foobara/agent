require "foobara/llm_backed_command"

module Foobara
  class Agent
    class DetermineInputsForNextCommand < Foobara::LlmBackedCommand
      class << self
        attr_accessor :command_class

        def command_cache
          @command_cache ||= {}
        end

        def clear_cache
          @command_cache = nil
        end

        def cached_command(agent_id, full_command_name)
          key = [agent_id, full_command_name]

          if command_cache.key?(key)
            command_cache[key]
          else
            command_cache[key] = yield
          end
        end

        def for(command_class:, agent_id:)
          cached_command(agent_id, command_class.full_command_name) do
            command_short_name = Util.non_full_name(command_class.command_name)
            class_name = "Foobara::Agent::#{agent_id}::DetermineInputsForNext#{command_short_name}Command"
            klass = Util.make_class_p(class_name, self)

            klass.command_class = command_class

            klass.description "Accepts a goal and context of the work so far and returns the inputs for " \
                              "the next #{command_short_name} command to run to make progress towards " \
                              "accomplishing the goal."

            klass.inputs do
              goal :string, :required, "What do you want the agent to attempt to accomplish?"
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

      description "Accepts a goal and context of the work so far and returns the inputs for the next command to " \
                  "run to make progress towards accomplishing the mission."

      inputs do
        goal :string, :required, "What do you want the agent to attempt to accomplish?"
        context Context, :required, "Context of the current mission so far"
        command_class :duck, :required, "Command to run to accomplish the goal"
        llm_model :string,
                  one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                  default: "claude-3-7-sonnet-20250219",
                  description: "The model to use for the LLM"
      end

      result :duck,
             description: "Inputs to pass to the next command to run to make progress " \
                          "towards accomplishing the mission."
    end
  end
end
