require_relative "list_commands"

module Foobara
  class Agent < CommandConnector
    class AccomplishGoal < Foobara::Command
      # Using a const here so we can stub it in the test suite to speed things up
      SECONDS_PER_MINUTE = 60

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
        max_llm_calls_per_minute :integer, :allow_nil
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
        unless list_commands_already_ran?
          simulate_describe_list_commands_command
          simulate_list_commands_run
        end
        # simulate_describe_command_run_for_all_commands

        until mission_accomplished or given_up or killed
          increment_command_calls
          check_if_too_many_calls

          throttle_llm_calls_if_necessary

          determine_next_command_and_inputs

          run_next_command
        end

        if given_up
          add_given_up_error
        end

        build_result
      end

      attr_accessor :next_command_name, :next_command_inputs, :next_command_raw_inputs, :mission_accomplished,
                    :given_up, :next_command_class, :next_command, :command_outcome, :timed_out,
                    :final_result, :final_message, :command_response, :delayed_command_name,
                    :command_calls, :killed

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

      def determine_next_command_and_inputs(retries = 3, error_outcome = nil)
        return if killed

        if retries == 0
          # TODO: test this path by irreparably breaking the needed commands
          # :nocov:
          self.next_command_name = GiveUp.full_command_name
          self.next_command_inputs = {
            message_to_user: "While trying to choose the next command and inputs, " \
                             "I've ran into an error several times that I couldn't figure out how to get past. " \
                             "The last error looked like this:\n#{error_outcome.errors_hash}"
          }
          self.next_command_raw_inputs = next_command_inputs

          return
          # :nocov:
        end

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

            if need_to_describe_next_command?
              simulate_describe_command
              return determine_next_command_and_inputs(retries, outcome)
            end

            if next_command_has_inputs?
              outcome = validate_next_command_inputs

              unless outcome.success?
                # TODO: test this path
                # :nocov:
                log_command_outcome(
                  command_name: next_command_name,
                  inputs: next_command_inputs,
                  outcome:
                )

                simulate_describe_command

                determine_next_command_and_inputs(retries - 1, outcome)
                # :nocov:
              end
            else
              self.next_command_inputs = {}
              self.next_command_raw_inputs = next_command_inputs
            end
          else
            log_command_outcome(
              command_name: next_command_name,
              inputs: next_command_inputs,
              outcome:,
              result: nil
            )

            determine_next_command_and_inputs(retries - 1, outcome)
          end
        else
          log_command_outcome(
            command_name: determine_command.class.full_command_name,
            inputs: determine_command.inputs&.except(:context),
            outcome:,
            result: outcome.result || determine_command.raw_result
          )

          determine_next_command_and_inputs(retries - 1, outcome)
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
        inputs_type = next_command_class.inputs_type

        NestedTransactionable.with_needed_transactions_for_type(inputs_type) do
          inputs_type.process_value(next_command_inputs)
        end
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
          prefix = agent_name && !agent_name.empty? ? "#{agent_name}: " : ""

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

      def build_result
        {
          message_to_user: final_message,
          result_data: final_result
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

      def llm_calls_in_last_minute
        llm_call_timestamps.select { |t| t > (Time.now - 60) }
      end

      def llm_call_count_in_last_minute
        llm_calls_in_last_minute.size
      end

      def time_until_llm_call_count_in_last_minute_changes
        calls = llm_calls_in_last_minute

        first_to_expire = calls.first

        if first_to_expire
          [0, (first_to_expire + SECONDS_PER_MINUTE) - Time.now].max
        else
          # TODO: figure out how to test this code path
          # :nocov:
          0
          # :nocov:
        end
      end

      def throttle_llm_calls_if_necessary
        return unless max_llm_calls_per_minute && max_llm_calls_per_minute > 0

        if llm_call_count_in_last_minute >= max_llm_calls_per_minute
          seconds = time_until_llm_call_count_in_last_minute_changes
          if verbose?
            (io_out || $stdout).puts "Sleeping for #{seconds} seconds to avoid LLM calls per minute limit"
          end

          sleep seconds
        end
      end

      def context
        agent.context
      end
    end
  end
end
