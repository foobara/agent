module Foobara
  class Agent < CommandConnector
    class DetermineNextCommand < DetermineBase
      description "Returns the name of the next command to run given the progress  " \
                  "towards accomplishing the current goal. " \
                  "If the goal has been accomplished it will choose the " \
                  "NotifyUserThatCurrentGoalHasBeenAccomplished command."

      result :string,
             description: "Name of the next command to run"
    end
  end
end
