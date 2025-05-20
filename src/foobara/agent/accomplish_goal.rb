require_relative "list_commands"

module Foobara
  # TODO: should agent maybe be a command connector? It feels a bit more like a command connector.
  module Agent
    class AccomplishGoal < Foobara::Command
      possible_error :gave_up, context: { reason: :string }, message: "Gave up."

      inputs do
        agent_name :string, "Name of the agent", default: SecureRandom.hex(4)
        goal :string, :required, "What do you want the agent to attempt to accomplish?"
        # TODO: we should be able to specify a subclass as a type
        command_classes [:duck], :required, "Commands that can be ran to accomplish the goal"
        final_result_type :duck, "Specifies how the result of the goal is to be structured"
      end

      result :duck

      depends_on ListCommands

      def execute
        build_initial_context
        build_command_connector
        connect_agent_commands
        connect_user_provided_commands

        until mission_accomplished or given_up or timed_out
          determine_next_command_name

          if command_described?
            fetch_next_command_class
            determine_next_command_inputs
          else
            choose_describe_command_instead
            fetch_next_command_class
          end

          run_next_command
          log_command_outcome
        end

        if given_up
          add_given_up_error
        end

        build_result
      end

      attr_accessor :context, :next_command_name, :next_command_inputs, :mission_accomplished, :given_up,
                    :command_connector, :next_command_class, :next_command, :command_outcome, :timed_out,
                    :final_result, :final_message, :command_response

      def build_initial_context
        # TODO: shouldn't have to pass command_log here since it has a default, debug that
        self.context = Context.new(command_log: [])
      end

      def build_command_connector
        self.command_connector = Connector.new(
          accomplish_goal_command: self,
          default_serializers: [
            Foobara::CommandConnectors::Serializers::ErrorsSerializer,
            Foobara::CommandConnectors::Serializers::AtomicSerializer,
            Foobara::CommandConnectors::Serializers::JsonSerializer
          ]
        )
      end

      def connect_agent_commands
        command_classes = [
          DescribeCommand,
          DescribeType,
          GiveUp,
          ListCommands,
          ListTypes
        ]

        command_classes << if result_type
                             EndSessionBecauseGoalHasBeenAccomplished.for(
                               result_type: final_result_type,
                               agent_id: agent_name
                             )
                           else
                             EndSessionBecauseGoalHasBeenAccomplished
                           end

        command_classes.each do |command_class|
          command_connector.connect(command_class, inputs: set_command_connector)
        end
      end

      def set_command_connector
        @set_command_connector ||= SetCommandConnectorInputsTransformer.for(command_connector)
      end

      def connect_user_provided_commands
        command_classes.each do |command_class|
          command_connector.connect(command_class)
        end
      end

      def determine_next_command_name
        if context.command_log.empty?
          self.next_command_name = ListCommands.full_command_name
        else
          command_class = DetermineNextCommand.for(command_class_names: all_command_classes, agent_id: agent_name)
          self.next_command_name = command_class.run!(goal:, context:)
        end
      end

      def choose_describe_command_instead
        self.next_command_inputs = { command_name: next_command_name }
        self.next_command_name = DescribeCommand.full_command_name
      end

      def all_command_classes
        @all_command_classes ||= run_subcommand!(ListCommands, command_connector:).values.flatten
      end

      def fetch_next_command_class
        self.next_command_class = command_connector.transformed_command_from_name(next_command_name)
      end

      def determine_next_command_inputs
        if context.command_log.empty?
          self.next_command_inputs = { command_name: ListCommands.full_command_name }
        else
          command_class = DetermineInputsForNextCommand.for(command_class: next_command_class, agent_id: agent_name)
          self.next_command_inputs = command_class.run!(goal:, context:)
        end
      end

      def run_next_command
        self.command_response = command_connector.run(
          full_command_name: next_command_name,
          inputs: next_command_inputs,
          action: "run"
        )

        self.command_outcome = command_response.outcome
      end

      def log_command_outcome
        outcome_hash = { success: command_outcome.success? }

        if command_outcome.success?
          outcome_hash[:result] = command_response.body
        else
          outcome_hash[:errors_hash] = command_response.body
        end

        context.command_log << CommandLogEntry.new(
          command_name: next_command_name,
          inputs: next_command_inputs,
          outcome: outcome_hash
        )
      end

      # TODO: these are awkwardly called from outside. Come up with a better solution.
      def mission_accomplished!(final_result, message)
        self.mission_accomplished = true
        self.final_result = final_result
        self.final_message = message
      end

      def give_up!(message)
        self.given_up = true
        self.final_message = message
      end

      def add_given_up_error
        add_runtime_error(:gave_up, reason: final_message)
      end

      def build_result
        final_result
      end

      def command_described?
        described_commands.include?(next_command_name)
      end

      def described_commands
        @described_commands ||= Set.new
      end
    end
  end
end
