module Foobara
  module Agent
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

        command_description
      end

      attr_accessor :command_class

      def find_command_class
        self.command_class = command_connector.lookup_command(command_name)
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
        command_description[:inputs_type] = JsonSchemaGenerator.to_json_schema(command_class.inputs_type)
      end

      def set_result_type
        command_description[:result_type] = JsonSchemaGenerator.to_json_schema(command_class.result_type)
      end
    end
  end
end
