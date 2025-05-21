require "foobara/all"
require "foobara/ai"
require "foobara/command_connectors"

module Foobara
  class Agent
    foobara_domain!

    foobara_depends_on Foobara::Ai::AnswerBot

    class << self
      def reset_all
        [
          DetermineInputsForNextCommand,
          DetermineNextCommand,
          EndSessionBecauseGoalHasBeenAccomplished
        ].each do |command_class|
          command_class.clear_cache
          Util.descendants(command_class).each(&:clear_cache)
        end
      end
    end
  end
end

Foobara::Util.require_directory "#{__dir__}/../../src"
Foobara::Monorepo.project "agent", project_path: "#{__dir__}/../../"
