require_relative "determine_base"

module Foobara
  class Agent < CommandConnector
    class DetermineNextCommandNameAndInputs < DetermineBase
      description "Returns the name of the next command to run and its inputs given the progress  " \
                  "towards accomplishing the current goal. " \
                  "If the goal has been accomplished it will choose the " \
                  "NotifyUserThatCurrentGoalHasBeenAccomplished command."

      result do
        command_name :string, :required
        inputs :attributes, :allow_nil
      end
    end
  end
end
