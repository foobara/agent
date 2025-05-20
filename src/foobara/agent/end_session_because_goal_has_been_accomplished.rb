module Foobara
  module Agent
    class EndSessionBecauseGoalHasBeenAccomplished < Foobara::Command
      class << self
        attr_accessor :command_class

        def command_cache
          @command_cache ||= {}
        end

        def cached_command(agent_id, result_type)
          key = [agent_id, result_type]

          if command_cache.key?(key)
            command_cache[key]
          else
            command_cache[key] = yield
          end
        end

        def for(result_type:, agent_id:)
          cached_command(agent_id, result_type) do
            command_name = "Foobara::Agent::#{agent_id}::EndSessionBecauseGoalHasBeenAccomplished"
            klass = Util.make_class_p(command_name, self)

            # TODO: handle duplicate colliding short command names!
            mod = Util.make_module_p("Foobara::Agent::#{agent_id}")
            mod.const_set("EndSessionBecauseGoalHasBeenAccomplished", klass)

            klass.description "Ends the session giving a final result formatted according to the " \
                              "result schema if relevant and an optional message to the user."

            inputs do
              # TODO: Are we still not able to uses classes as foobara types??
              command_connector :duck, :required, "Connector to end"
              message_to_user :string, "Optional message to the user"
            end

            if result_type
              add_inputs do
                result_data(*result_type)
              end

              klass.result(*result_type)

              klass.description "Ends the session giving a final result formatted according to the " \
                                "result schema and an optional message to the user."
            else
              klass.description "Ends the session giving an optional message to the user."
            end

            klass
          end
        end
      end

      description "Ends the session giving a final result formatted according to the " \
                  "result schema if relevant and an optional message to the user."

      inputs do
        # TODO: Are we still not able to uses classes as foobara types??
        command_connector :duck, :required, "Connector to end"
        message_to_user :string, "Optional message to the user"
        result_data :duck, "The final result of the work if relevant/expected"
      end

      def execute
        mark_mission_accomplished

        parsed_result
      end

      def mark_mission_accomplished
        command_connector.mark_mission_accomplished(result_data, message_to_user)
      end

      def parsed_result
        if result_data && result_type
          binding.pry
          JSON.parse(result_data)
        end
      end
    end
  end
end
