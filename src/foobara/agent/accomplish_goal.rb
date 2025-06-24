require_relative "list_commands"

module Foobara
  class Agent < CommandConnector
    class AccomplishGoal < Foobara::Command
      possible_error :gave_up, context: { reason: :string }, message: "Gave up."
      possible_error :too_many_command_calls,
                     context: { maximum_command_calls: :integer }

      inputs do
        goal :string, :required, "What do you want the agent to attempt to accomplish?"
        # TODO: we should be able to specify a subclass as a type
        final_result_type :duck, "Specifies how the result of the goal is to be structured"
        include_message_to_user_in_result :boolean, default: true
        verbose :boolean, default: false
        io_out :duck
        io_err :duck
        agent Agent, :required
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
        message_to_user :string, :allow_nil, "Message to the user about successfully accomplishing the goal"
        result_data :duck, "Optional result data to return to the user if final_result_type was given"
      end

      depends_on ListCommands

      def execute
        build_initial_context_if_necessary

        simulate_list_commands_run
        simulate_describe_command_run_for_all_commands

        until mission_accomplished or given_up
          increment_command_calls
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

      attr_accessor :context, :next_command_name, :next_command_inputs, :mission_accomplished, :given_up,
                    :next_command_class, :next_command, :command_outcome, :timed_out,
                    :final_result, :final_message, :command_response, :delayed_command_name,
                    :command_calls

      def build_initial_context_if_necessary
        # TODO: shouldn't have to pass command_log here since it has a default, debug that
        self.context = current_context || Context.new(command_log: [])
      end

      def simulate_list_commands_run
        return unless context.command_log.empty?

        self.next_command_name = ListCommands.full_command_name
        self.next_command_inputs = nil
        fetch_next_command_class

        run_next_command
        log_last_command_outcome
      end

      def simulate_describe_command_run_for_all_commands
        return if context.command_log.size > 1

        ListCommands.run!(command_connector: agent)[:user_provided_commands].each do |full_command_name|
          next if described_commands.include?(full_command_name)

          self.next_command_name = DescribeCommand.full_command_name
          self.next_command_inputs = { command_name: full_command_name }
          fetch_next_command_class

          run_next_command
          log_last_command_outcome
        end
      end

      def determine_next_command_and_inputs(retries = 2)
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
          # :nocov:
          Outcome.errors(e.errors)
          # :nocov:
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

        NestedTransactionable.with_needed_transactions_for_type(inputs_type) do
          inputs_type.process_value(next_command_inputs)
        end
      end

      def command_name_type
        @command_name_type ||= Agent.foobara_type_from_declaration(:string, one_of: all_command_classes)
      end

      def determine_next_command_name(retries = 2)
        self.next_command_name = if delayed_command_name
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
                                     # :nocov:
                                     Outcome.errors(e.errors)
                                     # :nocov:
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
        @all_command_classes ||= run_subcommand!(ListCommands, command_connector: agent).values.flatten
      end

      def fetch_next_command_class
        self.next_command_class = agent.transformed_command_from_name(next_command_name)
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
                                       # :nocov:
                                       Outcome.errors(e.errors)
                                       # :nocov:
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
        if verbose?
          (io_out || $stdout).puts "Running #{next_command_name} with #{next_command_inputs}"
        end

        self.command_response = agent.run(
          full_command_name: next_command_name,
          inputs: next_command_inputs,
          action: "run"
        )

        self.command_outcome = command_response.outcome

        if verbose?
          if command_outcome.success?
            (io_out || $stdout).puts "Command #{command_response.command.class.full_command_name} succeeded"
          else
            # :nocov:
            (io_err || $stderr).puts(
              "Command #{command_response.command.class.full_command_name} failed #{command_outcome.errors_hash}"
            )
            # :nocov:
          end
        end
      end

      def log_last_command_outcome
        log_command_outcome(command: command_response.command)
      end

      def increment_command_calls
        self.command_calls ||= -1
        self.command_calls += 1
      end

      def check_if_too_many_calls
        if command_calls > maximum_command_calls
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

      def agent_name
        agent.agent_name
      end

      def verbose?
        verbose
      end
    end
  end
end
