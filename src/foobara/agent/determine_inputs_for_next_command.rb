module Foobara
  module Agent
    class DetermineInputsForNextCommand < Foobara::LlmBackedCommand
      class << self
        def command_cache
          @command_cache ||= {}
        end

        def cached_command(agent_id, full_command_name)
          key = [agent_id, full_command_name]

          if command_cache.key?[key]
            command_cache[key]
          else
            command_cache[key] = yield
          end
        end

        def for(command_class:, agent_id:)
          cached_command(agent_id) do
            klass = Class.new(self)

            command_short_name = command_class.scoped_short_name

            # TODO: handle duplicate colliding short command names!
            Object.const_set("Foobara::Agent::#{agent_id}::DetermineInputsForNext#{command_short_name}Command", klass)

            klass.description "Accepts a goal and context of the work so far and returns the inputs for " \
                              "the next #{command_short_name} command to run to make progress towards " \
                              "accomplishing the goal."

            klass.inputs do
              goal :string, :required, "What do you want the agent to attempt to accomplish?"
              context Context, :required, "Context of the progress towards the goal so far"
            end

            klass.result command_class.inputs_type

            klass
          end
        end
      end

      description "Accepts a goal and context of the work so far and returns the inputs for the next command to " \
                  "run to make progress towards accomplishing the mission."

      inputs do
        goal :string, :required, "What do you want the agent to attempt to accomplish?"
        context Context, :required, "Context of the current mission so far"
        command_classes [Command], :required, "Commands that can be ran to accomplish the goal"
      end

      result :string, "Name of the next command to run to make progress towards accomplishing the mission."
    end
  end
end
