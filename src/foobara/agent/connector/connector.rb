require "foobara/command_connectors"

module Foobara
  class Agent
    class Connector < Foobara::CommandConnector
      attr_accessor :accomplish_goal_command, :agent_commands_connected

      def initialize(*, accomplish_goal_command:, **)
        self.accomplish_goal_command = accomplish_goal_command
        super(*, **)
      end

      def mark_mission_accomplished(final_result, message_to_user)
        # TODO: this is a pretty awkward way to communicate between commands hmmm...
        # maybe see if there's a less hacky way to pull this off.
        accomplish_goal_command.mission_accomplished!(final_result, message_to_user)
      end

      def give_up(reason)
        accomplish_goal_command.give_up!(reason)
      end

      def agent_commands_connected?
        agent_commands_connected
      end
    end
  end
end
