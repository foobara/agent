module Foobara
  class Agent < CommandConnector
    class NotifyUserThatCurrentGoalHasBeenAccomplished < Foobara::Command
      extend Concerns::SubclassCacheable

      class << self
        attr_accessor :command_class

        def for(result_type:, agent_id:)
          cached_subclass([result_type, agent_id]) do
            command_name = "Foobara::Agent::#{agent_id}::NotifyUserThatCurrentGoalHasBeenAccomplished"
            klass = Util.make_class_p(command_name, self)

            klass.description "Notifies the user that the current goal has been accomplished and returns a final " \
                              "result formatted according to the " \
                              "result schema and an optional message to the user. " \
                              "The user might issue a new goal."

            inputs do
              command_connector CommandConnector, :required, "Connector to notify user through"
              message_to_user :string, :required, "Message to the user about what was done"
            end

            if result_type
              add_inputs do
                result_data result_type, :required
              end

              klass.result do
                message_to_user :string, :required
                result_data result_type, :required
              end
              klass.description "Notifies the user that the current goal has been accomplished and returns a final " \
                                "result formatted according to the " \
                                "result schema if relevant and an optional message to the user. " \
                                "The user might issue a new goal."

            else
              # TODO: test this code path
              # :nocov:
              klass.description "Notifies the user that the current goal has been accomplished and, if relevant,  " \
                                "returns a final " \
                                "result formatted according to the " \
                                "result schema and an optional message to the user. " \
                                "The user might issue a new goal."
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
        message_to_user :string, :required, "Message to the user about what was done"
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
