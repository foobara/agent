module Foobara
  class Agent < CommandConnector
    class CommandLogEntry < Foobara::Model
      attributes do
        command_name :string, :required, "Name of the command that was run"
        inputs :attributes, :allow_nil, "Inputs to the command"
        outcome :required do
          success :boolean, :required, "Whether the command succeeded or not"
          result :duck, "Result of the command"
          # TODO: create a type for error hash structure
          errors_hash :duck, "Errors that occurred during the command"
        end
      end
    end
  end
end
