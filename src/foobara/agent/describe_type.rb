module Foobara
  module Agent
    class DescribeType < Foobara::Command
      inputs do
        command_connector :duck, :required, "Connector to find relevant type in"
        type_name :string, :required, "Name of the type to describe"
      end

      result :duck, description: "Information about the type"

      def execute
        find_type

        set_type_name
        set_json_schema

        type_description
      end

      attr_accessor :type

      def find_type
        self.type = command_connector.lookup_type(type_name)
      end

      def type_description
        @type_description ||= {}
      end

      def set_type_name
        type_description[:full_type_name] = type.scoped_full_name
      end

      def set_json_schema
        type_description[:json_schema] = JsonSchemaGenerator.to_json_schema(type)
      end
    end
  end
end
