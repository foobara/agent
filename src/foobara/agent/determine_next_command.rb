module Foobara
  module Agent
    class DetermineNextCommand < Foobara::LlmBackedCommand
      class << self
        def command_cache
          @command_cache ||= {}
        end

        def cached_command(agent_id)
          if command_cache.key?[agent_id]
            command_cache[agent_id]
          else
            command_cache[agent_id] = yield
          end
        end

        def for(command_classes:, agent_id:)
          cached_command(agent_id) do
            klass = Class.new(self)

            Object.const_set("Foobara::Agent::#{agent_id}::DetermineNextCommand", klass)

            klass.inputs do
              goal :string, :required, "What do you want the agent to attempt to accomplish?"
              context Context, :required, "Context of the current mission so far"
            end

            klass.result :string,
                         one_of: command_classes.map(&:full_command_name),
                         description: "Name of the next command to run to make progress towards accomplishing the mission"

            klass
          end
        end
      end

      description "Accepts a goal and context of the work so far and returns the name of the next command to run to " \
                  "make progress towards accomplishing the mission."

      inputs do
        goal :string, :required, "What do you want the agent to attempt to accomplish?"
        context Context, :required, "Context of the current mission so far"
        command_classes [Command], :required, "Commands that can be ran to accomplish the goal"
      end

      result :string, "Name of the next command to run to make progress towards accomplishing the mission."
    end
  end
end
