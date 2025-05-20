require "foobara/llm_backed_command"

module Foobara
  class Agent
    class DetermineInputsForNextCommand < Foobara::LlmBackedCommand
      class << self
        attr_accessor :command_class

        def command_cache
          @command_cache ||= {}
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
            klass = Class.new(self)
            klass.command_class = command_class

            command_short_name = Util.non_full_name(command_class.command_name)

            # TODO: handle duplicate colliding short command names!
            mod = Util.make_module_p("Foobara::Agent::#{agent_id}")
            mod.const_set("DetermineInputsForNext#{command_short_name}Command", klass)

            klass.description "Accepts a goal and context of the work so far and returns the inputs for " \
                              "the next #{command_short_name} command to run to make progress towards " \
                              "accomplishing the goal."

            klass.inputs do
              goal :string, :required, "What do you want the agent to attempt to accomplish?"
              context Context, :required, "Context of the progress towards the goal so far"
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
      end

      result :duck,
             description: "Inputs to pass to the next command to run to make progress " \
                          "towards accomplishing the mission."

      def execute
        if has_inputs?
          super
        else
          {}
        end
      end

      def command_class
        inputs[:command_class] || self.class.command_class
      end

      def has_inputs?
        command_class.inputs_type && !command_class.inputs_type.element_types.empty?
      end
    end
  end
end
