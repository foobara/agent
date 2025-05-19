module Foobara
  module Agent
    class Connector < Foobara::CommandConnector
      attr_accessor :accomplish_goal_command

      def initialize(*, accomplish_goal_command:, **)
        self.accomplish_goal_command = accomplish_goal_command
        connect_agent_commands
        super(*, **)
      end

      def connect_agent_commands
        [
          DescribeCommand,
          DescribeType,
          EndSessionBecauseGoalHasBeenAccomplished,
          GiveUp,
          ListCommands,
          ListTypes
        ].each do |command_class|
          connect(command_class, inputs: set_command_connector)
        end
      end

      def set_command_connector
        @set_command_connector ||= SetCommandConnectorInputsTransformer.for(self)
      end
    end
  end
end
