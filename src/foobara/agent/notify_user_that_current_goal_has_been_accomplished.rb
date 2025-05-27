module Foobara
  class Agent
    class EndSessionBecauseGoalHasBeenAccomplished < Foobara::Command
      extend Concerns::SubclassCacheable

      class << self
        attr_accessor :command_class

        def for(result_type:, agent_id:)
          cached_subclass([result_type, agent_id]) do
            command_name = "Foobara::Agent::#{agent_id}::EndSessionBecauseGoalHasBeenAccomplished"
            klass = Util.make_class_p(command_name, self)

            klass.description "Ends the session giving a final result formatted according to the " \
                              "result schema if relevant and an optional message to the user."

            inputs do
              # TODO: Are we still not able to uses classes as foobara types??
              command_connector :duck, :required, "Connector to end"
              message_to_user :string, "Optional message to the user"
            end

            if result_type
              add_inputs do
                result_data result_type
              end

              klass.result do
                message_to_user :string
                result_data result_type
              end

              klass.description "Ends the session giving a final result formatted according to the " \
                                "result schema and an optional message to the user."
            else
              # TODO: test this code path
              # :nocov:
              klass.description "Ends the session giving an optional message to the user."
              # :nocov:
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
        data = if result_type
                 inputs[:result_data]
               end
        command_connector.mark_mission_accomplished(data, message_to_user)
      end

      def parsed_result
        h = { message_to_user: }

        if inputs[:result_data] && result_type
          h[:result_data] = result_data
        end

        h
      end
    end
  end
end
