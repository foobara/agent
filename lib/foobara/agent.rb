require "foobara/all"
require "foobara/ai"

module Foobara
  module Agent
    foobara_domain!

    foobara_depends_on Foobara::Ai::AnswerBot
  end
end

Foobara::Util.require_directory "#{__dir__}/../../src"
