module Foobara
  module Agent
    class GiveUp < Foobara::Command
      inputs do
        command_connector :duck, :required, "Connector to end"
        message_to_user :string, "Optional message to the user explaining why you decided to give up"
      end

      def execute
        binding.pry
        mark_given_up

        nil
      end

      def mark_given_up
        command_connector.give_up(message_to_user)
      rescue => e
        binding.pry
        raise
      end
    end
  end
end
