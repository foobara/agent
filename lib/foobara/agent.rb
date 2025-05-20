require "foobara/all"
require "foobara/ai"
require "foobara/command_connectors"

module Foobara
  class Agent
    foobara_domain!

    foobara_depends_on Foobara::Ai::AnswerBot
  end
end

Foobara::Util.require_directory "#{__dir__}/../../src"
