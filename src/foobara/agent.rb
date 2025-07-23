module Foobara
  class Agent < CommandConnector
    StateMachine = Foobara::StateMachine.for(
      [:initialized, :idle, :error, :failure] => {
        kill: :killed,
        accomplish_goal: :accomplishing_goal
      },
      accomplishing_goal: {
        goal_accomplished: :idle,
        goal_errored: :error,
        goal_failed: :failure,
        kill: :killed
      }
    )

    attr_accessor :context,
                  :agent_name,
                  :agent_id,
                  :llm_model,
                  :current_accomplish_goal_command,
                  :result_type,
                  :include_message_to_user_in_result,
                  :agent_commands_connected,
                  :verbose,
                  :io_out,
                  :io_err,
                  :pass_aggregates_to_llm,
                  :result_entity_depth,
                  :maximum_command_calls

    def initialize(
      context: nil,
      agent_name: nil,
      command_classes: nil,
      llm_model: nil,
      result_type: nil,
      include_message_to_user_in_result: true,
      verbose: false,
      io_out: nil,
      io_err: nil,
      result_entity_depth: AssociationDepth::AGGREGATE,
      pass_aggregates_to_llm: nil,
      maximum_command_calls: nil,
      **opts
    )
      # TODO: shouldn't have to pass command_log here since it has a default, debug that
      self.context = context || Context.new(command_log: [])

      if agent_name
        self.agent_name = agent_name
      end
      self.agent_id = agent_name || "Anon#{SecureRandom.hex(2)}"
      self.llm_model = llm_model || Ai.default_llm_model
      self.result_type = result_type
      self.include_message_to_user_in_result = include_message_to_user_in_result
      self.verbose = verbose
      self.io_out = io_out
      self.io_err = io_err
      self.result_entity_depth = result_entity_depth
      self.pass_aggregates_to_llm = pass_aggregates_to_llm
      self.maximum_command_calls = maximum_command_calls

      pre_commit_transformer = if pass_aggregates_to_llm
                                 CommandConnectors::Transformers::LoadAggregatesPreCommitTransformer
                               else
                                 CommandConnectors::Transformers::LoadAtomsPreCommitTransformer
                               end

      opts = opts.merge(default_pre_commit_transformers: [
        *opts[:default_pre_commit_transformers],
        pre_commit_transformer
      ].uniq)

      super(**opts)

      # TODO: push this convenience method up into base class?
      command_classes&.each do |command_class|
        connect(command_class)
      end
    end

    def connect(*args, **opts)
      args, opts = desugarize_connect_args(args, opts)

      inputs_transformers = opts[:inputs_transformers] || []
      inputs_transformers = Util.array(inputs_transformers)
      inputs_transformers << CommandConnectors::Transformers::EntityToPrimaryKeyInputsTransformer

      # unless opts.key?(:aggregate_entities)
      #   opts = opts.merge(aggregate_entities: true)
      # end

      super(*args, **opts.merge(inputs_transformers:))
    end

    def run(*args, **)
      if args.first.is_a?(::String)
        accomplish_goal(*args, **)
      else
        unless agent_commands_connected?
          connect_agent_commands
        end

        super
      end
    end

    def state_machine
      @state_machine ||= StateMachine.new
    end

    def kill!
      current_accomplish_goal_command&.kill!
      state_machine.perform_transition!(:kill) do
        if context
          context.current_goal.state = Goal::States::KILLED
        end
      end
    end

    def killed?
      state_machine.current_state == Goal::States::KILLED
    end

    def accomplish_goal(
      goal,
      result_type: nil,
      maximum_command_calls: nil,
      llm_model: nil
    )
      set_context_goal(goal)

      if result_type && self.result_type != result_type
        if self.result_type
          # :nocov:
          raise ArgumentError, "You can only specify a result type once"
          # :nocov:
        elsif agent_commands_connected?
          # :nocov:
          raise ArgumentError, "You can't specify a result type this late in the process"
          # :nocov:
        else
          self.result_type = result_type
        end
      end

      unless agent_commands_connected?
        connect_agent_commands
      end

      state_machine.perform_transition!(:accomplish_goal)

      begin
        inputs = accomplish_goal_inputs(goal, result_type:, maximum_command_calls:, llm_model:)

        self.current_accomplish_goal_command = AccomplishGoal.new(inputs)

        current_accomplish_goal_command.run.tap do |outcome|
          transition = if outcome.success?
                         :goal_accomplished
                       else
                         :goal_failed
                       end

          unless killed?
            state_machine.perform_transition!(transition) do
              context.current_goal.state = if outcome.success?
                                             Goal::States::ACCOMPLISHED
                                           else
                                             Goal::States::FAILED
                                           end
            end
          end
        end
      rescue
        # :nocov:
        unless killed?
          state_machine.perform_transition!(:goal_errored) do
            context.current_goal.state = Goal::States::ERROR
          end
        end

        raise
        # :nocov:
      end
    end

    def accomplish_goal_inputs(goal,
                               result_type: nil,
                               maximum_command_calls: nil,
                               llm_model: nil)
      inputs = {
        goal:,
        final_result_type: self.result_type,
        agent: self
      }

      llm_model ||= self.llm_model

      if llm_model
        inputs[:llm_model] = llm_model
      end

      if maximum_command_calls.nil?
        maximum_command_calls = self.maximum_command_calls
      end

      unless maximum_command_calls.nil?
        inputs[:maximum_command_calls] = maximum_command_calls
      end

      if verbose
        inputs[:verbose] = verbose
      end

      if io_out
        inputs[:io_out] = io_out
      end

      if io_err
        inputs[:io_err] = io_err
      end

      if include_message_to_user_in_result || include_message_to_user_in_result == false
        inputs[:include_message_to_user_in_result] = include_message_to_user_in_result
      end

      if result_entity_depth
        inputs[:result_entity_depth] = result_entity_depth
      end

      unless pass_aggregates_to_llm.nil?
        inputs[:pass_aggregates_to_llm] = pass_aggregates_to_llm
      end

      inputs
    end

    def set_context_goal(goal)
      context.set_new_goal(goal)
    end

    def mark_mission_accomplished(final_result, message_to_user)
      # TODO: this is a pretty awkward way to communicate between commands hmmm...
      # maybe see if there's a less hacky way to pull this off.
      current_accomplish_goal_command.mission_accomplished!(final_result, message_to_user)
    end

    def give_up(reason)
      current_accomplish_goal_command.give_up!(reason)
    end

    def agent_commands_connected?
      agent_commands_connected
    end

    def connect_agent_commands
      command_classes = [
        DescribeCommand,
        DescribeType,
        GiveUp,
        ListCommands
      ]

      command_classes << if result_type || include_message_to_user_in_result
                           # TODO: Support changing the final result type when the goal changes
                           NotifyUserThatCurrentGoalHasBeenAccomplished.for(
                             result_type:,
                             agent_id:,
                             # TODO: Support changing this flag when the goal changes
                             include_message_to_user_in_result:,
                             result_entity_depth:
                           )
                         else
                           NotifyUserThatCurrentGoalHasBeenAccomplished
                         end

      set_command_connector_transformer = SetCommandConnectorInputsTransformer.for(self)

      command_classes.each do |command_class|
        connect(command_class, inputs: set_command_connector_transformer)
      end

      self.agent_commands_connected = true
    end
  end
end
