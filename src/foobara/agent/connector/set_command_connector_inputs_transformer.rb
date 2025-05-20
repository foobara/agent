module Foobara
  class Agent
    class SetCommandConnectorInputsTransformer < TypeDeclarations::TypedTransformer
      class << self
        attr_accessor :command_connector

        def for(command_connector)
          Class.new(self).tap do |subclass|
            subclass.command_connector = command_connector
          end
        end
      end

      def command_connector
        self.class.command_connector
      end

      def from_type_declaration
        to_declaration = to_type.declaration_data
        TypeDeclarations::Attributes.reject(to_declaration, :command_connector)
      end

      def transform(inputs)
        inputs.merge(command_connector:)
      end
    end
  end
end
