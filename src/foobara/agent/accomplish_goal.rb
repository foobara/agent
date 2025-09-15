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
        maximum_command_calls :integer,
                              :allow_nil,
                              default: 25,
                              description: "Maximum number of commands to run before giving up"
        llm_model :string,
                  :allow_nil,
                  one_of: Ai::AnswerBot::Types::ModelEnum,
                  default: Ai.default_llm_model,
                  description: "The model to use for the LLM"
        user_association_depth :symbol, :allow_nil, one_of: Foobara::AssociationDepth
        result_entity_depth :symbol, :allow_nil, one_of: Foobara::AssociationDepth
        pass_aggregates_to_llm :boolean, :allow_nil
      end

      result do
        message_to_user :string, :allow_nil, "Message to the user about successfully accomplishing the goal"
        result_data :duck, "Optional result data to return to the user if final_result_type was given"
      end

      depends_on ListCommands

      def execute
        simulate_list_commands_run unless list_commands_already_ran?

        until mission_accomplished? or given_up? or killed?
          check_if_too_many_calls
          determine_next_command_and_inputs

          unless command_already_described?
            choose_describe_command_command_instead
          end

          if command_inputs_valid?
            run_next_command
          else
            increment_and_check_retry_count
          end
        end

        add_given_up_error if given_up?

        build_result
      end

      attr_accessor :next_command_name, :next_command_inputs, :next_command_raw_inputs, :mission_accomplished,
                    :given_up, :next_command_class, :next_command, :command_outcome, :timed_out,
                    :final_result, :final_message, :command_response, :delayed_command_name,
                    :command_calls, :killed, :retry_count, :error_outcome

      def list_commands_already_ran?
        context.command_log.any? { |log_entry| log_entry.command_name =~ /\bListCommands\z/ }
      end

      def simulate_list_commands_run
        self.next_command_name = ListCommands.full_command_name
        self.next_command_raw_inputs = nil
        self.next_command_inputs = nil
        fetch_next_command_class

        run_next_command
      end

      def simulate_describe_list_commands_command
        self.next_command_name = DescribeCommand.full_command_name
        self.next_command_inputs = { command_name: ListCommands.full_command_name }
        self.next_command_raw_inputs = next_command_inputs
        fetch_next_command_class

        run_next_command
      end

      def simulate_describe_command(command_name = next_command_name)
        old_next_command_name = next_command_name
        old_next_command_inputs = next_command_inputs
        old_next_command_raw_inputs = next_command_raw_inputs
        old_next_command_class = next_command_class

        self.next_command_name = DescribeCommand.full_command_name
        self.next_command_inputs = { command_name: }
        self.next_command_raw_inputs = next_command_inputs
        fetch_next_command_class

        run_next_command

        self.next_command_name = old_next_command_name
        self.next_command_inputs = old_next_command_inputs
        self.next_command_raw_inputs = old_next_command_raw_inputs
        self.next_command_class = old_next_command_class
      end

      def simulate_describe_command_run_for_all_commands
        # TODO: currently not using this code path. Unclear if it is worth it.
        # :nocov:
        return if context.command_log.size > 1

        ListCommands.run!(command_connector: agent)[:user_provided_commands].each do |full_command_name|
          next if command_described?(full_command_name)

          self.next_command_name = DescribeCommand.full_command_name
          self.next_command_inputs = { command_name: full_command_name }
          self.next_command_raw_inputs = next_command_inputs
          fetch_next_command_class

          run_next_command
        end
        # :nocov:
      end

      def determine_next_command_and_inputs
        return if killed

        compact_command_log

        inputs_for_determine = { agent:, llm_model: }
        unless pass_aggregates_to_llm.nil?
          inputs_for_determine[:pass_aggregates_to_llm] = pass_aggregates_to_llm
        end
        determine_command = DetermineNextCommandNameAndInputs.new(inputs_for_determine)

        outcome = begin
          record_llm_call_timestamp
          determine_command.run
        rescue CommandPatternImplementation::Concerns::Result::CouldNotProcessResult => e
          # :nocov:
          Outcome.errors(e.errors)
          # :nocov:
        end

        if outcome.success?
          self.next_command_name = outcome.result[:command]
          self.next_command_inputs = outcome.result[:inputs]
          self.next_command_raw_inputs = next_command_inputs

          outcome = validate_next_command_name

          if outcome.success?
            fetch_next_command_class
          else
            log_command_outcome(
              command_name: next_command_name,
              inputs: next_command_inputs,
              outcome:,
              result: nil
            )

            self.error_outcome = outcome
            increment_and_check_retry_count
            determine_next_command_and_inputs
          end
        else
          log_command_outcome(
            command_name: determine_command.class.full_command_name,
            inputs: determine_command.inputs&.except(:context),
            outcome:,
            result: outcome.result || determine_command.raw_result
          )

          self.error_outcome = outcome
          increment_and_check_retry_count
          determine_next_command_and_inputs
        end
      end

      def validate_next_command_name
        if next_command_name.is_a?(::String)
          command_class = agent.transformed_command_from_name(next_command_name)

          if command_class
            self.next_command_name = command_class.full_command_name

            return Outcome.success(next_command_name)
          end
        end

        outcome = command_name_type.process_value(next_command_name)

        if outcome.success?
          # TODO: figure out a way to hit this path in the test suite
          # :nocov:
          self.next_command_name = outcome.result
          # :nocov:
        end

        outcome
      end

      def validate_next_command_inputs
        if next_command_has_inputs?
          inputs_type = next_command_class.inputs_type

          outcome = NestedTransactionable.with_needed_transactions_for_type(inputs_type) do
            inputs = next_command_inputs.nil? ? {} : next_command_inputs
            inputs_type.process_value(inputs)
          end

          valid = outcome.success?
          self.command_inputs_valid = valid

          if valid
            self.next_command_inputs = outcome.result
            # Do we really need this raw inputs variable?
            self.next_command_raw_inputs = next_command_inputs
          else # TODO: test this path
            # :nocov:
            log_command_outcome(
              command_name: next_command_name,
              inputs: next_command_inputs,
              outcome:
            )
            # :nocov:
          end
        else
          self.command_inputs_valid = true
          self.next_command_inputs = {}
          self.next_command_raw_inputs = next_command_inputs
        end
      end

      def command_inputs_valid?
        command_inputs_valid
      end

      def command_name_type
        @command_name_type ||= Agent.foobara_type_from_declaration(:string, one_of: all_command_classes)
      end

      def all_command_classes
        @all_command_classes ||= run_subcommand!(ListCommands, command_connector: agent).values.flatten
      end

      def fetch_next_command_class
        self.next_command_class = agent.transformed_command_from_name(next_command_name)
      end

      def next_command_has_inputs?
        type = next_command_class.inputs_type
        type && !empty_attributes?(type)
      end

      def run_next_command
        increment_command_calls
        reset_retry_count

        log_command_code(command_name: next_command_name, inputs: next_command_inputs)

        self.command_response = agent.run(
          full_command_name: next_command_name,
          inputs: next_command_inputs,
          action: "run"
        )

        self.command_outcome = command_response.outcome

        log_command_outcome(command: command_response.command, log_command_code: false)
      end

      def compact_command_log
        # Rules:
        # Delete errors for any command that has succeeded since
        # Delete all but the last DescribeCommand call for a given
        describe_command_call_indexes = {}
        commands = {}

        describe_command_name = DescribeCommand.full_command_name
        context.command_log.each.with_index do |command_log_entry, index|
          command_name = command_log_entry.command_name

          if command_name == describe_command_name
            described_command = command_log_entry.inputs[:command_name]

            if command_log_entry.outcome[:success]
              describe_command_call_indexes[described_command] ||= []
              describe_command_call_indexes[described_command] << index
            end
          end

          commands[command_name] ||= [[], []]
          bucket_index = command_log_entry.outcome[:success] ? 0 : 1
          commands[command_name][bucket_index] << index
        end

        indexes_to_delete = []

        describe_command_call_indexes.each_value do |indexes|
          indexes_to_delete += indexes[0..-2]
        end

        commands.each_value do |(success_indexes, failure_indexes)|
          last_success = success_indexes.last
          next unless last_success

          failure_indexes.each do |failure_index|
            # TODO: test this path
            # :nocov:
            if failure_index < last_success
              indexes_to_delete << failure_index
            else
              break
            end
            # :nocov:
          end
        end

        if indexes_to_delete.empty?
          return
        end

        new_log = []
        context.command_log = context.command_log.each.with_index do |entry, index|
          unless indexes_to_delete.include?(index)
            new_log << entry
          end
        end

        context.command_log = new_log
      end

      MAX_RETRY_COUNT = 3

      def increment_and_check_retry_count
        self.retry_count ||= 0
        self.retry_count += 1

        if retry_count > MAX_RETRY_COUNT
          # TODO: test this path by irreparably breaking the needed commands
          # :nocov:
          self.next_command_name = GiveUp.full_command_name
          self.next_command_inputs = {
            message_to_user: "While trying to choose the next command and inputs, " \
                             "I've ran into an error several times that I couldn't figure out how to get past. " \
                             "The last error looked like this:\n#{error_outcome.errors_hash}"
          }
          self.next_command_raw_inputs = next_command_inputs
          # :nocov:
        elsif verbose?
          # :nocov:
          (io_err || $stderr).puts " !!! Retrying to determine next command and inputs. " \
                                   "Retries left: #{RETRY_COUNT - retry_count}"
          # :nocov:
        end
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

      def log_command_outcome(command: nil,
                              command_name: nil,
                              inputs: nil,
                              outcome: nil,
                              result: nil,
                              log_command_code: true)
        if command
          command_name ||= command.class.full_command_name
          inputs ||= command.raw_inputs
          outcome ||= command.outcome
        end

        if outcome&.success?
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

        if verbose?
          if log_command_code
            # TODO: test this code path hmmm
            # :nocov:
            self.log_command_code(command_name:, inputs:)
            # :nocov:
          end

          unless log_entry.success?
            # :nocov:
            (io_err || $stderr).puts(
              "Command #{log_entry.command_name} failed:\n#{log_entry.errors_hash}"
            )
            # :nocov:
          end
        end
      end

      def log_command_code(command_name:, inputs:)
        if verbose?
          args = if next_command_inputs.nil? || next_command_inputs.empty?
                   ""
                 else
                   s = next_command_inputs.to_s

                   if s =~ /\A\{(.*)}\z/
                     "(#{::Regexp.last_match(1)})"
                   else
                     # :nocov:
                     raise "Unexpected next_command_inputs: #{next_command_inputs}"
                     # :nocov:
                   end
                 end

          agent_name = agent.agent_name
          prefix = if agent_name && !agent_name.empty?
                     "#{agent_name}<#{llm_model}>: "
                   else
                     # Not setting an agent_name results in non-determinism in NotifyUser... command
                     # namespace. This results in problems in the test suite making this code path a little
                     # harder to test indirectly.
                     # :nocov:
                     ""
                     # :nocov:
                   end

          (io_out || $stdout).puts "#{prefix}#{next_command_name}.run#{args}"
        end
      end

      # TODO: these are awkwardly called from outside. Come up with a better solution.
      def mission_accomplished!(final_result, message)
        self.mission_accomplished = true
        self.final_result = final_result
        self.final_message = message
      end

      def kill!
        self.killed = true
      end

      def give_up!(message)
        self.given_up = true
        self.final_message = message
      end

      def add_given_up_error
        add_runtime_error(:gave_up, reason: final_message)
      end

      def final_result_type_from_declaration
        return @final_result_type_from_declaration if defined?(@final_result_type_from_declaration)

        @final_result_type_from_declaration = if final_result_type
                                                if final_result_type.is_a?(Types::Type)
                                                  final_result_type
                                                else
                                                  domain = result_type.created_in_namespace.foobara_domain
                                                  domain.foobara_type_from_declaration(final_result_type)
                                                end
                                              end
      end

      def build_result
        result_data = if final_result_type_from_declaration
                        outcome = final_result_type_from_declaration.process_value(final_result)

                        if outcome.success?
                          outcome.result
                        elsif given_up? || killed?
                          final_result
                        else
                          # :nocov:
                          raise CommandPatternImplementation::Concerns::Result::CouldNotProcessResult,
                                outcome.errors
                          # :nocov:
                        end
                      else
                        final_result
                      end

        {
          message_to_user: final_message,
          result_data:
        }
      end

      def described_commands
        @described_commands ||= Set.new
      end

      def empty_attributes?(type)
        type.extends_type?(BuiltinTypes[:attributes]) && type.element_types.empty?
      end

      def verbose?
        verbose
      end

      def need_to_describe_next_command?
        return false if command_described?(next_command_name)
        return false if next_command_name == DescribeCommand.full_command_name
        return true if next_command_has_inputs?

        # check if inputs were unexpectedly given for a command that doesn't need them,
        # in which case we should describe it
        next_command_inputs && !next_command_inputs.empty?
      end

      def command_described?(command_name)
        described_commands.include?(command_name)
      end

      def llm_call_timestamps
        @llm_call_timestamps ||= []
      end

      attr_writer :llm_call_timestamps

      def record_llm_call_timestamp
        llm_call_timestamps.unshift(Time.now)
      end

      def context
        agent.context
      end

      def mission_accomplished?
        mission_accomplished
      end

      def given_up?
        given_up
      end

      def killed?
        killed
      end
    end
  end
end
