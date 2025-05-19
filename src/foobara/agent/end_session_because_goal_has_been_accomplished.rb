module Foobara
  module Agent
    class EndSessionBecauseGoalHasBeenAccomplished < Foobara::Command
      inputs do
        command_connector Connector, :required, "Connector to end"
        message_to_user :string, "Optional message to the user"
      end

      def execute
        mark_mission_accomplished

        nil
      end

      def mark_mission_accomplished
        command_connector.mark_mission_accomplished(message)
      end
    end
  end
end
