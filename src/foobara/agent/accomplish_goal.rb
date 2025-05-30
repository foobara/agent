require_relative "list_commands"

module Foobara
  # TODO: should agent maybe be a command connector? It feels a bit more like a command connector.
  class Agent
    class AccomplishGoal < Foobara::Command
      possible_error :gave_up, context: { reason: :string }, message: "Gave up."
      possible_error :too_many_command_calls,
                     context: { maximum_command_calls: :integer }

      inputs do
        agent_name :string, "Name of the agent"
        goal :string, :required, "What do you want the agent to attempt to accomplish?"
        # TODO: we should be able to specify a subclass as a type
        command_classes [Class], "Commands that can be ran to accomplish the goal"
        final_result_type :duck, "Specifies how the result of the goal is to be structured"
        existing_command_connector CommandConnector, :allow_nil,
                                   "A connector containing already-connected commands for the agent to use"
        current_context Context, :allow_nil, "The current context of the agent"
        maximum_command_calls :integer,
                              :allow_nil,
                              default: 25,
                              description: "Maximum number of commands to run before giving up"
        llm_model :string,
                  :allow_nil,
                  one_of: Foobara::Ai::AnswerBot::Types::ModelEnum,
                  default: "claude-3-7-sonnet-20250219",
                  description: "The model to use for the LLM"
        log_successful_determine_command_and_inputs_outcomes(
          :boolean,
          default: true,
          description: "You can experiment with turning this off " \
                       "if you want to see what happens if we don't log " \
                       "successful command/input selection outcomes"
        )
        choose_next_command_and_next_inputs_separately :boolean,
                                                       default: false,
                                                       description:
                                                         "By default, asks for next command and inputs together. " \
                                                         "You can experiment with getting the separately " \
                                                         "with this flag if you wish."
      end

      result do
        message_to_user :string, :required, "Message to the user about successfully accomplishing the goal"
        result_data :duck, "Optional result data to return to the user if final_result_type was given"
      end

      depends_on ListCommands

      def execute
        build_initial_context_if_necessary

        if command_connector_passed_in?
          set_accomplished_goal_command
        else
          build_command_connector
          connect_user_provided_commands
        end

        unless agent_commands_connected?
          connect_agent_commands
        end

        until mission_accomplished or given_up
          check_if_too_many_calls
          if choose_next_command_and_next_inputs_separately?
            determine_next_command_then_inputs_separately
          else
            determine_next_command_and_inputs
          end

          run_next_command
          log_last_command_outcome
        end

        if given_up
          add_given_up_error
        end

        build_result
      end

      def agent_commands_connected?
        command_connector.agent_commands_connected?
      end

      def validate
        validate_either_command_classes_or_connector_given
      end

      def validate_either_command_classes_or_connector_given
        # TODO: implement this!
      end

      attr_accessor :context, :next_command_name, :next_command_inputs, :mission_accomplished, :given_up,
                    :next_command_class, :next_command, :command_outcome, :timed_out,
                    :final_result, :final_message, :command_response, :delayed_command_name
      attr_writer :command_connector

      def agent_name
        @agent_name ||= inputs[:agent_name] || "Anon#{SecureRandom.hex(2)}"
      end

      def build_initial_context_if_necessary
        # TODO: shouldn't have to pass command_log here since it has a default, debug that
        self.context = current_context || Context.new(command_log: [])
      end

      def command_connector_passed_in?
        existing_command_connector
      end

      def command_connector
        @command_connector ||= existing_command_connector
      end

      def build_command_connector
        self.command_connector ||= Connector.new(
          accomplish_goal_command: self,
          default_serializers: [
            Foobara::CommandConnectors::Serializers::ErrorsSerializer,
            Foobara::CommandConnectors::Serializers::AtomicSerializer
          ],
          llm_model:
        )
      end

      def set_accomplished_goal_command
        command_connector.accomplish_goal_command = self
      end

      def connect_agent_commands
        command_connector.connect_agent_commands(final_result_type:, agent_name:)
      end

      def connect_user_provided_commands
        command_classes.each do |command_class|
          command_connector.connect(command_class)
        end
      end

      def determine_next_command_and_inputs(retries = 2)
        if context.command_log.empty?
          self.next_command_name = ListCommands.full_command_name
          self.next_command_inputs = nil
          fetch_next_command_class
          return
        end

        inputs_for_determine = {
          goal:,
          context:,
          llm_model:,
          command_class_names: all_command_classes
        }

        determine_command = DetermineNextCommandNameAndInputs.new(inputs_for_determine)

        outcome = begin
          determine_command.run
        rescue CommandPatternImplementation::Concerns::Result::CouldNotProcessResult => e
          Outcome.errors(e.errors)
        end

        if outcome.success?
          self.next_command_name = outcome.result[:command_name]
          self.next_command_inputs = outcome.result[:inputs]

          outcome = validate_next_command_name

          if outcome.success?
            fetch_next_command_class

            if next_command_has_inputs?
              outcome = validate_next_command_inputs

              if outcome.success?
                if log_successful_determine_command_and_inputs_outcomes?
                  log_command_outcome(
                    command: determine_command,
                    inputs: determine_command.inputs.except(:context)
                  )
                end
              else
                log_command_outcome(
                  command: determine_command,
                  inputs: determine_command.inputs.except(:context),
                  outcome:,
                  result: outcome.result || determine_command.raw_result
                )

                determine_next_command_inputs
              end
            else
              self.next_command_inputs = {}
            end
          else
            log_command_outcome(
              command: determine_command,
              inputs: determine_command.inputs&.except(:context),
              outcome:,
              result: outcome.result || determine_command.raw_result
            )

            if retries > 0
              determine_next_command_and_inputs(retries - 1)
            else
              determine_next_command_then_inputs_separately
            end
          end
        else
          log_command_outcome(
            command_name: determine_command.class.full_command_name,
            inputs: determine_command.inputs&.except(:context),
            outcome:,
            result: outcome.result || determine_command.raw_result
          )

          if retries > 0
            determine_next_command_and_inputs(retries - 1)
          else
            determine_next_command_then_inputs_separately
          end
        end
      end

      def determine_next_command_then_inputs_separately
        determine_next_command_name

        if command_described?
          fetch_next_command_class
          determine_next_command_inputs
        else
          choose_describe_command_instead
          fetch_next_command_class
        end
      end

      def validate_next_command_name
        outcome = command_name_type.process_value(next_command_name)

        if outcome.success?
          self.next_command_name = outcome.result
        end

        outcome
      end

      def validate_next_command_inputs
        inputs_type = next_command_class.inputs_type

        outcome = NestedTransactionable.with_needed_transactions_for_type(inputs_type) do
          inputs_type.process_value(next_command_inputs)
        end

        if outcome.success?
          self.next_command_inputs = outcome.result
        end

        outcome
      end

      def command_name_type
        @command_name_type ||= Agent.foobara_type_from_declaration(:string, one_of: all_command_classes)
      end

      def determine_next_command_name(retries = 2)
        self.next_command_name = if context.command_log.empty?
                                   ListCommands.full_command_name
                                 elsif delayed_command_name
                                   name = delayed_command_name
                                   self.delayed_command_name = nil
                                   name
                                 else
                                   command_class = DetermineNextCommand.for(
                                     command_class_names: all_command_classes, agent_id: agent_name
                                   )

                                   inputs = { goal:, context: }
                                   if llm_model
                                     inputs[:llm_model] = llm_model
                                   end

                                   command = command_class.new(inputs)
                                   outcome = begin
                                     command.run
                                   rescue CommandPatternImplementation::Concerns::Result::CouldNotProcessResult => e
                                     Outcome.errors(e.errors)
                                   end

                                   if outcome.success?
                                     if log_successful_determine_command_and_inputs_outcomes?
                                       log_command_outcome(
                                         command:,
                                         inputs: command.inputs.except(:context),
                                         outcome:
                                       )
                                     end
                                   else
                                     # TODO: either figure out a way to hit this path in the test suite or delete it
                                     # :nocov:
                                     log_command_outcome(
                                       command:,
                                       inputs: command.inputs.except(:context),
                                       outcome:,
                                       result: outcome.result || command.raw_result
                                     )

                                     if retries > 0
                                       return determine_next_command_name(retries - 1)
                                     end
                                     # :nocov:
                                   end

                                   outcome.raise!
                                   outcome.result
                                 end
      end

      def choose_describe_command_instead
        self.delayed_command_name = next_command_name
        self.next_command_inputs = { command_name: next_command_name }
        self.next_command_name = DescribeCommand.full_command_name
      end

      def all_command_classes
        @all_command_classes ||= run_subcommand!(ListCommands, command_connector:).values.flatten
      end

      def fetch_next_command_class
        self.next_command_class = command_connector.transformed_command_from_name(next_command_name)
      end

      def determine_next_command_inputs(retries = 2)
        self.next_command_inputs = if next_command_has_inputs?
                                     command_class = command_class_for_determine_inputs_for_next_command

                                     inputs = { goal:, context: }
                                     if llm_model
                                       inputs[:llm_model] = llm_model
                                     end

                                     command = command_class.new(inputs)
                                     outcome = begin
                                       command.run
                                     rescue CommandPatternImplementation::Concerns::Result::CouldNotProcessResult => e
                                       Outcome.errors(e.errors)
                                     end

                                     if outcome.success?
                                       if log_successful_determine_command_and_inputs_outcomes?
                                         log_command_outcome(
                                           command:,
                                           inputs: command.inputs.except(:context),
                                           outcome:
                                         )
                                       end
                                     else
                                       # TODO: either figure out a way to hit this path in the test suite or delete it
                                       # :nocov:
                                       log_command_outcome(
                                         command:,
                                         inputs: command.inputs.except(:context),
                                         outcome:,
                                         result: outcome.result || command.raw_result
                                       )
                                       if retries > 0
                                         return determine_next_command_inputs(retries - 1)
                                       end
                                       # :nocov:
                                     end

                                     outcome.raise!
                                     outcome.result
                                   end
      end

      def next_command_has_inputs?
        type = next_command_class.inputs_type
        type && !empty_attributes?(type)
      end

      def command_class_for_determine_inputs_for_next_command
        DetermineInputsForNextCommand.for(
          command_class: next_command_class, agent_id: agent_name
        )
      end

      def run_next_command
        self.command_response = command_connector.run(
          full_command_name: next_command_name,
          inputs: next_command_inputs,
          action: "run"
        )

        self.command_outcome = command_response.outcome
      end

      def log_last_command_outcome
        log_command_outcome(command: command_response.command)
      end

      def check_if_too_many_calls
        if context.command_log.size > maximum_command_calls
          add_runtime_error(
            :too_many_command_calls,
            "Too many command calls. " \
            "Stopping. Increase maximum_command_calls if #{maximum_command_calls} is not enough.",
            maximum_command_calls:
          )
        end
      end

      def log_command_outcome(command: nil, command_name: nil, inputs: nil, outcome: nil, result: nil)
        if command
          command_name ||= command.class.full_command_name
          inputs ||= command.inputs
          outcome ||= command.outcome
          result ||= outcome.result
        end

        outcome_hash = { success: outcome.success? }

        if outcome.success? || result
          outcome_hash[:result] = result
        end

        unless outcome.success?
          outcome_hash[:errors_hash] = outcome.errors_hash
        end

        log_entry = CommandLogEntry.new(
          command_name:,
          inputs:,
          outcome: outcome_hash
        )

        context.command_log << log_entry
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
        {
          message_to_user: final_message,
          result_data: final_result
        }
      end

      def command_described?
        described_commands.include?(next_command_name)
      end

      def described_commands
        @described_commands ||= Set.new
      end

      def empty_attributes?(type)
        type.extends_type?(BuiltinTypes[:attributes]) && type.element_types.empty?
      end

      def log_successful_determine_command_and_inputs_outcomes?
        log_successful_determine_command_and_inputs_outcomes
      end

      def choose_next_command_and_next_inputs_separately?
        choose_next_command_and_next_inputs_separately
      end
    end
  end
end
