module Foobara
  module Agent
    class ListTypes < Foobara::Command
      inputs do
        command_connector :duck, :required, "Connector to fetch types from"
      end

      result [:string]

      def execute
        construct_type_list

        type_list
      end

      attr_accessor :type_list

      def construct_type_list
        self.type_list = command_connector.all_exposed_type_names
      end
    end
  end
end
