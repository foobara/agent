module Foobara
  class Agent < CommandConnector
    class Goal < Foobara::Model
      module States
        ACCOMPLISHED = :accomplished
        KILLED = :killed
        FAILED = :failed
        ERROR = :error
        GAVE_UP = :gave_up
      end

      attributes do
        text :string, :required
        state :symbol, :allow_nil, one_of: States
      end
    end
  end
end
