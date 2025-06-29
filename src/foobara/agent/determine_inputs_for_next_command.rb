module Foobara
  class Agent < CommandConnector
    class DetermineInputsForNextCommand < DetermineBase
      extend Concerns::SubclassCacheable

      class << self
        def for(command_class:, agent_id:)
          cached_subclass([command_class.full_command_name, agent_id]) do
            command_short_name = Util.non_full_name(command_class.command_name)
            class_name = "Foobara::Agent::#{agent_id}::DetermineInputsForNext#{command_short_name}Command"
            klass = Util.make_class_p(class_name, self)

            klass.description "Returns the inputs for " \
                              "the next #{command_class.full_command_name} command to run."

            if command_class.inputs_type.nil? || command_class.inputs_type.element_types.empty?
              # :nocov:
              raise ArgumentError, "command #{command_class.full_command_name} has no inputs"
              # :nocov:
            end

            transformer = CommandConnectors::Transformers::EntityToPrimaryKeyInputsTransformer.new(
              to: command_class.inputs_type
            )
            klass.result transformer.from_type

            klass
          end
        end
      end
    end
  end
end
