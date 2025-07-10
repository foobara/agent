require_relative "goal"

module Foobara
  class Agent < CommandConnector
    class Context < Foobara::Model
      class << self
        def for(goal)
          new(command_log: [], current_goal: Goal.new(text: goal))
        end
      end

      attributes do
        current_goal Goal, :required, "The current goal the agent needs to accomplish"
        previous_goals [Goal]
        # TODO: why doesn't this default of [] work as expected on newly created models?
        command_log [CommandLogEntry], default: [],
                                       description: "Log of all commands run so far and their outcomes"
      end

      def set_new_goal(goal)
        self.previous_goals ||= []
        previous_goals << current_goal
        self.current_goal = Goal.new(text: goal)
      end
    end
  end
end
