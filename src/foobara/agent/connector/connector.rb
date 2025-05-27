require "foobara/command_connectors"

module Foobara
  class Agent
    class Connector < Foobara::CommandConnector
      attr_accessor :accomplish_goal_command, :agent_commands_connected, :llm_model

      def initialize(*, accomplish_goal_command:, llm_model: nil, **)
        self.accomplish_goal_command = accomplish_goal_command
        self.llm_model = llm_model

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

      def connect_agent_commands(final_result_type: nil, agent_name: nil)
        command_classes = [
          DescribeCommand,
          DescribeType,
          GiveUp,
          ListCommands,
          ListTypes
        ]

        command_classes << if final_result_type
                             NotifyUserThatCurrentGoalHasBeenAccomplished.for(
                               result_type: final_result_type,
                               agent_id: agent_name
                             )
                           else
                             NotifyUserThatCurrentGoalHasBeenAccomplished
                           end

        command_classes.each do |command_class|
          connect(command_class, inputs: set_command_connector_transformer)
        end

        self.agent_commands_connected = true
      end

      def set_command_connector_transformer
        @set_command_connector_transformer ||= SetCommandConnectorInputsTransformer.for(self)
      end
    end
  end
end
