module Foobara
  class Agent
    class CommandLogEntry < Foobara::Model
      attributes do
        command_name :string, :required, "Name of the command that was run"
        inputs :duck, :required, "Inputs to the command" # TODO: Allow :attributes to be used as a type succesfully
        outcome :required do
          success :boolean, :required, "Whether the command succeeded or not"
          result :duck, :allow_nil, "Result of the command"
          # TODO: create a type for error hash structure
          errors_hash :duck, :allow_nil, "Errors that occurred during the command"
        end
      end
    end
  end
end
