require "io/wait"

module Foobara
  class Agent
    attr_accessor :context, :agent_command_connector, :agent_name, :llm_model

    def initialize(
      context: nil,
      agent_name: nil,
      command_classes: nil,
      agent_command_connector: nil,
      llm_model: nil
    )
      # TODO: shouldn't have to pass command_log here since it has a default, debug that
      self.context = context
      self.agent_command_connector = agent_command_connector
      self.agent_name = agent_name if agent_name
      self.llm_model = llm_model

      build_initial_context
      build_agent_command_connector

      command_classes&.each do |command_class|
        self.agent_command_connector.connect(command_class)
      end
    end

    def accomplish_goal(goal, result_type: nil)
      inputs = {
        goal:,
        final_result_type: result_type,
        current_context: context,
        existing_command_connector: agent_command_connector,
        agent_name:
      }

      if llm_model
        inputs[:llm_model] = llm_model
      end

      AccomplishGoal.run(inputs)
    end

    def run_cli(io_in: $stdin, io_out: $stdout, io_err: $stderr)
      io_out.write "> "
      io_out.flush

      loop do
        input_is_available = io_in.wait_readable(1)

        if input_is_available
          line = io_in.gets
          if line.nil?
            break
          end

          goal = line.chomp

          begin
            outcome = accomplish_goal(goal)

            if outcome.success?
              result = outcome.result
              io_out.puts
              io_out.puts result[:message_to_user]
              io_out.puts
              io_out.flush
            else
              # :nocov:
              io_out.puts
              io_err.puts outcome.errors_hash
              io_err.puts
              io_err.flush
              # :nocov:
            end

            io_out.write "> "
            io_out.flush
          rescue => e
            # :nocov:
            io_out.puts e.message
            io_err.puts e.message
            io_err.puts e.backtrace
            io_err.flush
            # :nocov:
          end
        end
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
          Foobara::CommandConnectors::Serializers::AtomicSerializer,
          Foobara::CommandConnectors::Serializers::JsonSerializer
        ]
      )
    end
  end
end
