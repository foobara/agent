module Foobara
  module Agent
    class GiveUp < Foobara::Command
      inputs do
        command_connector Connector, :required, "Connector to end"
        message_to_user :string, "Optional message to the user explaining why you decided to give up"
      end

      def execute
        mark_given_up

        nil
      end

      def mark_given_up
        command_connector.mark_given_up(message)
      end
    end
  end
end
