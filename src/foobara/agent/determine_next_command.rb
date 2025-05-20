require "foobara/llm_backed_command"

module Foobara
  class Agent
    class DetermineNextCommand < Foobara::LlmBackedCommand
      class << self
        attr_accessor :command_class_names

        def command_cache
          @command_cache ||= {}
        end

        def cached_command(agent_id)
          if command_cache.key?(agent_id)
            command_cache[agent_id]
          else
            command_cache[agent_id] = yield
          end
        end

        def for(command_class_names:, agent_id:)
          cached_command(agent_id) do
            command_name = "Foobara::Agent::#{agent_id}::DetermineNextCommand"
            klass = Util.make_class_p(command_name, self)

            klass.command_class_names = command_class_names

            klass.inputs do
              goal :string, :required, "What do you want the agent to attempt to accomplish?"
              context Context, :required, "Context of the current mission so far"
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
                  "make progress towards accomplishing the mission. Make sure you have called DescribeCommand the" \
                  "command first so that you will know how to construct its inputs in the next step."

      inputs do
        goal :string, :required, "What do you want the agent to attempt to accomplish?"
        context Context, :required, "Context of the current mission so far"
        # command_classes [Command], :required, "Commands that can be ran to accomplish the goal"
      end

      result :string, description: "Name of the next command to run to make progress towards accomplishing the mission."
    end
  end
end
