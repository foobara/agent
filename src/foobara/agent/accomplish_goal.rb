module Foobara
  # TODO: should agent maybe be a command connector? It feels a bit more like a command connector.
  module Agent
    class AccomplishGoal < Foobara::Command
      inputs do
        agent_name :string, "Name of the agent", default: SecureRandom.hex(4)
        goal :string, :required, "What do you want the agent to attempt to accomplish?"
        command_classes [Command], :required, "Commands that can be ran to accomplish the goal"
        result_type :duck, "Specifies how the result of the goal is to be structured"
      end

      result :duck

      def execute
        build_initial_context
        build_command_connector
        connect_commands

        until mission_accomplished_or_given_up
          determine_next_command_name
          fetch_next_command_class
          determine_next_command_inputs
          build_next_command
          run_next_command
          log_command_outcome
        end

        build_result
      end

      attr_accessor :context, :next_command_name, :next_command_inputs, :mission_accomplished, :given_up,
                    :command_connector

      def build_initial_context
        self.context = Context.new
      end

      def build_command_connector
        self.command_connector = command_connector
      end

      def connect_commands
        command_classes.each do |command_class|
          command_connector.connect(command_class)
        end
      end

      def mission_accomplished_or_given_up
        mission_accomplished || given_up
      end

      def determine_next_command_name
        command_class = DetermineNextCommand.for(command_classes:, agent_id: agent_name)
        self.next_command_name = run_subcommand!(command_class, goal:, context:)
      end

      def fetch_next_command_class
        self.command_class = command_connector.lookup_command(next_command_name)
      end

      def determine_next_command_inputs
        command_class = DetermineInputsForNextCommand.for(command_class: next_command_class, agent_id: agent_name)
        self.next_command_inputs = run_subcommand!(command_class, goal:, context:)
      end

      def build_next_command
        self.next_command = next_command_class.new(next_command_inputs)
      end

      def run_next_command
        self.next_command_outcome = next_command.run
      end

      def log_command_outcome
        outcome_hash = { success: next_command_outcome.success? }

        if next_command_outcome.success?
          outcome_hash[:result] = next_command_outcome.result
        else
          outcome_hash[:errors_hash] = next_command_outcome.errors_hash
        end

        context.command_log << CommandLogEntry.new(
          command_name: next_command_name,
          inputs: next_command_inputs,
          outcome: outcome_hash
        )
      end
    end
  end
end
