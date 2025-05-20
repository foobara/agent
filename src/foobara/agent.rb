module Foobara
  class Agent
    attr_accessor :context, :agent_command_connector, :agent_name

    def initialize(
      context: nil,
      agent_name: nil,
      command_classes: nil,
      agent_command_connector: nil
    )
      # TODO: shouldn't have to pass command_log here since it has a default, debug that
      self.context = context
      self.agent_command_connector = agent_command_connector
      self.agent_name = agent_name if agent_name

      build_initial_context
      build_agent_command_connector

      command_classes&.each do |command_class|
        self.agent_command_connector.connect(command_class)
      end
    end

    def accomplish_goal(goal, result_type: nil)
      AccomplishGoal.run(
        goal:,
        final_result_type: result_type,
        current_context: context,
        existing_command_connector: agent_command_connector,
        agent_name:
      )
    end

    def build_initial_context
      # TODO: shouldn't have to pass command_log here since it has a default, debug that
      self.context ||= Context.new(command_log: [])
    end

    def build_agent_command_connector
      self.agent_command_connector ||= Connector.new(
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
