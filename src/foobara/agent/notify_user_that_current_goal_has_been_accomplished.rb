module Foobara
  class Agent < CommandConnector
    # NOTE: we intentionally don't use a result type here
    # to reduce tokens the LLM has to deal with when this command is described
    class NotifyUserThatCurrentGoalHasBeenAccomplished < Foobara::Command
      extend Concerns::SubclassCacheable

      class << self
        attr_accessor :command_class, :returns_message_to_user, :returns_result_data, :result_is_attributes,
                      :built_result_type, :result_is_model

        def for(agent_id: nil, result_type: nil, include_message_to_user_in_result: true, result_entity_depth: nil)
          agent_id ||= "Anon#{SecureRandom.hex(2)}"

          cached_subclass([agent_id]) do
            command_name = "Foobara::Agent::#{agent_id}::NotifyUserThatCurrentGoalHasBeenAccomplished"
            klass = Util.make_class_p(command_name, self)

            klass.description "Notifies the user that the current goal has been accomplished and returns a final " \
                              "result formatted according to the " \
                              "result schema and an optional message to the user. " \
                              "The user might issue a new goal."

            if result_type
              klass.returns_result_data = true
              unless result_type.is_a?(Types::Type)
                result_type = Domain.current.foobara_type_from_declaration(result_type)
              end

              domain = result_type.created_in_namespace.foobara_domain

              # TODO: fix this... agent backed command sets these via its own result type.
              # check if message_to_user is already here and also search/fix result_data to be result for consistency.
              if include_message_to_user_in_result
                klass.returns_message_to_user = true

                klass.built_result_type = domain.foobara_type_from_declaration do
                  result result_type, :required
                  message_to_user :string, :required, "Message to the user about what was done"
                end

                klass.add_inputs klass.built_result_type

                klass.description "Notifies the user that the current goal has been accomplished and returns a final " \
                                  "result formatted according to the " \
                                  "result schema and a message to the user. " \
                                  "The user might issue a new goal."
              else
                if result_type.extends?(BuiltinTypes[:model]) &&
                   !result_type.extends?(BuiltinTypes[:detached_entity]) && result_type != BuiltinTypes[:model]
                  # TODO: Create a ModelToAttributesInputsTransformer in foobara gem and move this logic there
                  model_declaration = result_type.declaration_data

                  # Distinguishing between nil and no inputs might be tricky so if :allow_nil then
                  # we will prefer `result: nil` over `nil`
                  # if there's a description we'll also prefer result: so that the description will
                  # make it through to the LLM on that input.
                  # TODO: handle the model's description via the command's description instead.
                  if !model_declaration.key?(:allow_nil) && !model_declaration.key?(:description)
                    klass.built_result_type = result_type
                    klass.result_is_model = true
                    klass.add_inputs result_type.target_class.attributes_type
                  end
                end

                unless klass.result_is_model
                  if result_type.extends?(BuiltinTypes[:attributes])
                    klass.built_result_type = result_type
                    klass.result_is_attributes = true
                    klass.add_inputs result_type
                  else
                    klass.built_result_type = domain.foobara_type_from_declaration do
                      result result_type, :required
                    end
                    klass.add_inputs klass.built_result_type
                  end
                end

                klass.description "Notifies the user that the current goal has been accomplished and accepts a final " \
                                  "result value as inputs. " \
                                  "The user might issue a new goal."
              end
            elsif include_message_to_user_in_result
              klass.returns_message_to_user = true

              klass.add_inputs do
                message_to_user :string, :required, "Message to the user about what was done"
              end

              klass.description "Notifies the user that the current goal has been accomplished and results in a " \
                                "message to the user. " \
                                "The user might issue a new goal."
            else
              # This should be unreachable actually
              # :nocov:
              klass.description "Notifies the user that the current goal has been accomplished. " \
                                "The user might issue a new goal."
              # :nocov:
            end

            apply_result_data_transformer(klass, result_entity_depth)

            klass
          end
        end

        def result_data_transformer(result_entity_depth)
          if result_entity_depth
            case result_entity_depth
            when AssociationDepth::AGGREGATE
              CommandConnectors::Transformers::LoadAggregatesTransformer
            when AssociationDepth::ATOM
              CommandConnectors::Transformers::LoadAtomsTransformer
            else
              # :nocov:
              raise "Unsupported result entity depth: #{result_entity_depth}"
              # :nocov:
            end&.instance
          end
        end

        def apply_result_data_transformer(command_klass, result_entity_depth)
          transformer = result_data_transformer(result_entity_depth)
          return unless transformer

          inputs_type = command_klass.inputs_type
          return unless inputs_type

          if inputs_type.extends?(BuiltinTypes[:detached_entity]) ||
             DetachedEntity.contains_associations?(inputs_type)
            command_klass.before_commit_transaction do |command:, **|
              # TODO: why can't we just pass in the command??
              built_result = command.final_result_data

              if built_result
                transformer.process_value!(built_result)
              end
            end
          end
        end
      end

      description "Ends the session giving a final result formatted according to the " \
                  "result schema if relevant and an optional message to the user."

      inputs do
        command_connector CommandConnector, :required, "Connector to notify user through"
      end

      def execute
        extract_result_data_and_message_to_user
        mark_mission_accomplished

        nil
      end

      attr_accessor :final_result_data, :final_message_to_user

      def extract_result_data_and_message_to_user
        result, message = if returns_message_to_user?
                            inputs.values_at(:result, :message_to_user)
                          elsif returns_result_data?
                            if result_is_attributes?
                              inputs.slice(*self.class.built_result_type.element_types.keys)
                            elsif result_is_model?
                              inputs.slice(
                                *self.class.built_result_type.target_class.attributes_type.element_types.keys
                              )
                            else
                              [inputs[:result], nil]
                            end
                          end

        self.final_result_data = result
        self.final_message_to_user = message
      end

      def mark_mission_accomplished
        command_connector.mark_mission_accomplished(final_result_data, final_message_to_user)
      end

      def returns_message_to_user?
        self.class.returns_message_to_user
      end

      def returns_result_data?
        self.class.returns_result_data
      end

      def result_is_attributes?
        self.class.result_is_attributes
      end

      def result_is_model?
        self.class.result_is_model
      end
    end
  end
end
