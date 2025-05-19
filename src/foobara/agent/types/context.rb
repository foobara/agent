module Foobara
  module Agent
    class Context < Foobara::Model
      attributes do
        command_log [CommandLogEntry], default: [], description: "Log of all commands run so far and their outcomes"
      end
    end
  end
end
