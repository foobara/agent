module Foobara
  class Agent < CommandConnector
    class Context < Foobara::Model
      attributes do
        # TODO: why doesn't this default of [] work as expected on newly created models?
        command_log [CommandLogEntry], default: [],
                                       description: "Log of all commands run so far and their outcomes"
      end
    end
  end
end
