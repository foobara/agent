require "foobara/all"
require "foobara/ai"
require "foobara/command_connectors"

module Foobara
  class Agent < CommandConnector
    foobara_domain!

    foobara_depends_on Foobara::Ai::AnswerBot

    class << self
      def reset_all
        NotifyUserThatCurrentGoalHasBeenAccomplished.clear_subclass_cache
        Util.descendants(NotifyUserThatCurrentGoalHasBeenAccomplished).each(&:clear_subclass_cache)
      end
    end
  end
end

Foobara::Util.require_directory "#{__dir__}/../../src"
Foobara.project "agent", project_path: "#{__dir__}/../../"
