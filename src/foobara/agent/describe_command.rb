module Foobara
  class Agent < CommandConnector
    class DescribeCommand < Foobara::Command
      inputs do
        command_connector :duck, :required, "Connector to find relevant command in"
        command_name :string, :required, "Name of the command to describe"
      end

      result :duck, description: "Information about the command"

      def execute
        find_command_class

        set_command_name
        set_description
        set_inputs_type
        set_result_type

        mark_command_as_described

        command_description
      end

      attr_accessor :command_class

      def find_command_class
        self.command_class = command_connector.transformed_command_from_name(command_name)
      end

      def command_description
        @command_description ||= {}
      end

      def set_command_name
        command_description[:full_command_name] = command_class.full_command_name
      end

      def set_description
        command_description[:description] = command_class.description
      end

      def set_inputs_type
        if command_class.inputs_type
          command_description[:inputs_type] = JsonSchemaGenerator.to_json_schema(command_class.inputs_type)
        end
      end

      def set_result_type
        if command_class.result_type
          command_description[:result_type] = JsonSchemaGenerator.to_json_schema(command_class.result_type)
        end
      end

      def mark_command_as_described
        command_connector.accomplish_goal_command.described_commands << command_class.full_command_name
      end
    end
  end
end
