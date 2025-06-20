module Foobara
  class Agent < CommandConnector
    class NotifyUserThatCurrentGoalHasBeenAccomplished < Foobara::Command
      extend Concerns::SubclassCacheable

      class << self
        attr_accessor :command_class

        def for(agent_id: nil, result_type: nil, include_message_to_user_in_result: true)
          agent_id ||= "Anon#{SecureRandom.hex(2)}"

          cached_subclass([result_type, agent_id]) do
            command_name = "Foobara::Agent::#{agent_id}::NotifyUserThatCurrentGoalHasBeenAccomplished"
            klass = Util.make_class_p(command_name, self)

            klass.description "Notifies the user that the current goal has been accomplished and returns a final " \
                              "result formatted according to the " \
                              "result schema and an optional message to the user. " \
                              "The user might issue a new goal."

            inputs do
              command_connector CommandConnector, :required, "Connector to notify user through"
              # message_to_user :string, :required, "Message to the user about what was done"
            end

            if result_type
              if include_message_to_user_in_result
                add_inputs do
                  result result_type, :required
                  message_to_user :string, :required, "Message to the user about what was done"
                end

                klass.description "Notifies the user that the current goal has been accomplished and returns a final " \
                                  "result formatted according to the " \
                                  "result schema and a message to the user. " \
                                  "The user might issue a new goal."
              else
                add_inputs do
                  result result_type, :required
                end

                klass.description "Notifies the user that the current goal has been accomplished and returns a final " \
                                  "result formatted according to the " \
                                  "result schema. " \
                                  "The user might issue a new goal."
              end
            else
              # TODO: test this code path
              # :nocov:
              klass.description "Notifies the user that the current goal has been accomplished. " \
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
        message_to_user :string, "Message to the user about what was done"
        result :duck, "The final result of the work if relevant/expected"
      end

      def execute
        mark_mission_accomplished

        parsed_result
      end

      def mark_mission_accomplished
        command_connector.mark_mission_accomplished(inputs[:result], inputs[:message_to_user])
      end

      def parsed_result
        inputs.slice(:result, :message_to_user)
      end
    end
  end
end
