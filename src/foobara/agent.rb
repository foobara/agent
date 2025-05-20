module Foobara
  class Agent < CommandConnector
    def initialize(*, context: nil, **, &)
      # TODO: shouldn't have to pass command_log here since it has a default, debug that
      self.context = context
      build_initial_context
      build_agent_command_connector

      super(*, **, &)
    end

    def run(goal, result_type: nil)
      AccomplishGoal.run!(
        goal:,
        final_result_type: result_type,
        context: context,
        command_connector: agent_command_connector
      )
    end

    attr_accessor :context, :agent_command_connector

    def build_initial_context
      # TODO: shouldn't have to pass command_log here since it has a default, debug that
      self.context ||= Context.new(command_log: [])
    end

    def build_agent_command_connector
      self.command_connector = Connector.new(
        accomplish_goal_command: self,
        default_serializers: [
          Foobara::CommandConnectors::Serializers::ErrorsSerializer,
          Foobara::CommandConnectors::Serializers::AtomicSerializer,
          Foobara::CommandConnectors::Serializers::JsonSerializer
        ]
      )
    end
  end
end
