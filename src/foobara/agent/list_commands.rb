module Foobara
  class Agent < CommandConnector
    class ListCommands < Foobara::Command
      inputs do
        command_connector :duck, :required, "Connector to end"
      end

      result do
        user_provided_commands [:string], :required,
                               "List of commands the user would like you to choose from to accomplish the goal"
        agent_specific_commands [:string], :required,
                                "Commands available to all agents to introspect or end the session"
      end

      def execute
        construct_command_lists

        command_lists
      end

      attr_accessor :command_lists

      def construct_command_lists
        user_provided_commands = []
        agent_specific_commands = []

        command_connector.all_transformed_command_classes.each do |command_class|
          if command_class.domain == Foobara::Agent
            agent_specific_commands
          else
            user_provided_commands
          end << command_class.full_command_name
        end

        self.command_lists = { user_provided_commands:, agent_specific_commands: }
      end
    end
  end
end
