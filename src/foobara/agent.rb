module Foobara
  class Agent
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
                  :agent_command_connector,
                  :agent_name,
                  :llm_model,
                  :current_accomplish_goal_command,
                  :result_type

    def initialize(
      context: nil,
      agent_name: nil,
      command_classes: nil,
      agent_command_connector: nil,
      llm_model: nil,
      result_type: nil
    )
      # TODO: shouldn't have to pass command_log here since it has a default, debug that
      self.context = context
      self.agent_command_connector = agent_command_connector
      self.agent_name = agent_name if agent_name
      self.llm_model = llm_model
      self.result_type = result_type

      build_initial_context
      build_agent_command_connector

      command_classes&.each do |command_class|
        self.agent_command_connector.connect(command_class)
      end
    end

    def state_machine
      @state_machine ||= StateMachine.new
    end

    def kill!
      state_machine.perform_transition!(:kill)
    end

    def killed?
      state_machine.current_state == :killed
    end

    def accomplish_goal(
      goal,
      result_type: nil,
      choose_next_command_and_next_inputs_separately: nil,
      maximum_call_count: nil
    )
      if result_type && self.result_type != result_type
        if self.result_type
          # :nocov:
          raise ArgumentError, "You can only specify a result type once"
          # :nocov:
        elsif agent_command_connector.agent_commands_connected?
          # :nocov:
          raise ArgumentError, "You can't specify a result type this late in the process"
          # :nocov:
        else
          self.result_type = result_type
        end
      end

      state_machine.perform_transition!(:accomplish_goal)

      begin
        inputs = {
          goal:,
          final_result_type: self.result_type,
          current_context: context,
          existing_command_connector: agent_command_connector,
          agent_name:
        }

        if llm_model
          inputs[:llm_model] = llm_model
        end

        unless choose_next_command_and_next_inputs_separately.nil?
          inputs[:choose_next_command_and_next_inputs_separately] = choose_next_command_and_next_inputs_separately
        end

        unless maximum_call_count.nil?
          inputs[:maximum_command_calls] = maximum_call_count
        end

        self.current_accomplish_goal_command = AccomplishGoal.new(inputs)

        current_accomplish_goal_command.run.tap do |outcome|
          if outcome.success?
            state_machine.perform_transition!(:goal_accomplished)
          else
            state_machine.perform_transition!(:goal_errored)
          end
        end
      rescue
        # :nocov:
        state_machine.perform_transition!(:goal_failed)
        raise
        # :nocov:
      end
    end

    def build_initial_context
      # TODO: shouldn't have to pass command_log here since it has a default, debug that
      self.context ||= Context.new(command_log: [])
    end

    def build_agent_command_connector
      self.agent_command_connector ||= Connector.new(
        accomplish_goal_command: self,
        llm_model:,
        default_serializers: [
          Foobara::CommandConnectors::Serializers::ErrorsSerializer,
          Foobara::CommandConnectors::Serializers::AtomicSerializer
        ]
      )
    end
  end
end
