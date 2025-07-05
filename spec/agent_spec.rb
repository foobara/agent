RSpec.describe Foobara::Agent do
  after do
    Foobara.reset_alls
    if described_class.const_defined?(agent.agent_name)
      described_class.send(:remove_const, agent.agent_name)
    end
  end

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  let(:agent) do
    described_class.new(
      agent_name:,
      command_classes:,
      llm_model:,
      verbose:,
      io_out:,
      io_err:,
      include_message_to_user_in_result:,
      max_llm_calls_per_minute:
    )
  end
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }
  let(:agent_name) { "CapybaraAgent" }
  let(:llm_model) { "claude-3-7-sonnet-20250219" }
  let(:include_message_to_user_in_result) { true }
  let(:maximum_call_count) { nil }
  let(:verbose) { false }
  let(:io_out) { nil }
  let(:io_err) { nil }
  let(:max_llm_calls_per_minute) { nil }

  context "when there are some capybaras but one has a bad year of birth" do
    use_capybaras_domain

    before do
      Capybaras::CreateCapybara.run!(name: "Fumiko", year_of_birth: 2020)
      Capybaras::CreateCapybara.run!(name: "Barbara", year_of_birth: 19)
      Capybaras::CreateCapybara.run!(name: "Basil", year_of_birth: 2021)
    end

    let(:result_type) { Capybaras::Capybara }
    let(:command_classes) { [Capybaras::FindAllCapybaras, Capybaras::UpdateCapybara] }
    let(:goal) { "There is a capybara with a bad year of birth. Can you find and fix the bad record? Thanks!" }

    describe "#accomplish_goal" do
      let(:outcome) do
        agent.accomplish_goal(goal,
                              result_type:,
                              maximum_call_count:)
      end

      it "can fix the busted record and fix it back", vcr: { record: :none } do
        expect {
          expect(outcome).to be_success
          expect(result[:result_data].name).to eq("Barbara")
        }.to change {
          Capybaras::Capybara.transaction do
            Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
          end
        }.from(19).to(2019)

        expect {
          new_outcome = agent.accomplish_goal(
            "Thank you so much! Can you set it back so that I can do the demo over again? Thanks!",
            result_type:
          )
          expect(new_outcome).to be_success
          capy = new_outcome.result[:result_data]
          expect(capy.name).to eq("Barbara")
        }.to change {
          Capybaras::Capybara.transaction do
            Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
          end
        }.from(2019).to(19)
      end

      context "when result only" do
        let(:include_message_to_user_in_result) { false }

        it "can fix the busted record and fix it back", vcr: { record: :none } do
          expect {
            expect(outcome).to be_success
            expect(result[:result_data].name).to eq("Barbara")
          }.to change {
            Capybaras::Capybara.transaction do
              Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
            end
          }.from(19).to(2019)

          expect {
            new_outcome = agent.accomplish_goal(
              "Thank you so much! Can you set it back so that I can do the demo over again? Thanks!",
              result_type:
            )
            expect(new_outcome).to be_success
            capy = new_outcome.result[:result_data]
            expect(capy.name).to eq("Barbara")
          }.to change {
            Capybaras::Capybara.transaction do
              Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
            end
          }.from(2019).to(19)
        end

        context "when result is attributes" do
          let(:result_type) do
            Foobara::Domain.current.foobara_type_from_declaration do
              capybara Capybaras::Capybara, :required
            end
          end

          it "can fix the busted record and fix it back", vcr: { record: :none } do
            expect {
              expect(outcome).to be_success
              expect(result[:result_data][:capybara].name).to eq("Barbara")
            }.to change {
              Capybaras::Capybara.transaction do
                Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
              end
            }.from(19).to(2019)

            expect {
              new_outcome = agent.accomplish_goal(
                "Thank you so much! Can you set it back so that I can do the demo over again? Thanks!",
                result_type:
              )
              expect(new_outcome).to be_success

              capy = new_outcome.result[:result_data][:capybara]
              expect(capy.name).to eq("Barbara")
            }.to change {
              Capybaras::Capybara.transaction do
                Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
              end
            }.from(2019).to(19)
          end
        end
      end

      context "when verbose" do
        let(:verbose) { true }
        let(:io_out) { StringIO.new }
        let(:io_err) { StringIO.new }

        it "can fix the busted record and fix it back", vcr: { record: :none } do
          expect {
            expect(outcome).to be_success
            expect(result[:result_data].name).to eq("Barbara")
          }.to change {
            Capybaras::Capybara.transaction do
              Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
            end
          }.from(19).to(2019)

          expect {
            new_outcome = agent.run(
              "Thank you so much! Can you set it back so that I can do the demo over again? Thanks!",
              result_type:
            )
            expect(new_outcome).to be_success
            capy = new_outcome.result[:result_data]
            expect(capy.name).to eq("Barbara")
          }.to change {
            Capybaras::Capybara.transaction do
              Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
            end
          }.from(2019).to(19)
        end

        context "when throttling calls per minute" do
          let(:max_llm_calls_per_minute) { 2 }

          before do
            stub_const("Foobara::Agent::AccomplishGoal::SECONDS_PER_MINUTE", 1)
          end

          it "can fix the busted record", vcr: { record: :none } do
            expect {
              expect(outcome).to be_success
              expect(result[:result_data].name).to eq("Barbara")
            }.to change {
              Capybaras::Capybara.transaction do
                Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
              end
            }.from(19).to(2019)
          end
        end
      end

      context "when there are too many calls" do
        let(:maximum_call_count) { 1 }

        it "gives an expected error", vcr: { record: :none } do
          expect(outcome).to_not be_success
          expect(outcome.errors_hash.keys).to include("runtime.too_many_command_calls")
        end
      end

      context "when choosing command fails" do
        let(:maximum_call_count) { 50 }

        before do
          values = [{ bad: "inputs" }]

          allow(
            Foobara::Agent::DetermineNextCommandNameAndInputs
          ).to receive(:new).and_wrap_original { |method, *args, **opts|
            if values.empty?
              method.call(*args, **opts)
            else
              method.call(values.shift)
            end
          }
        end

        it "can fallback to choosing them separately", vcr: { record: :none } do
          expect {
            expect(outcome).to be_success
            expect(result[:result_data].name).to eq("Barbara")
          }.to change {
            Capybaras::Capybara.transaction do
              Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
            end
          }.from(19).to(2019)
        end
      end

      context "when choosing command gives a bad command name" do
        before do
          values = [{ command: "BadCommandName", inputs: { bad: "inputs" } }]
          allow_any_instance_of(
            Foobara::Agent::DetermineNextCommandNameAndInputs
          ).to receive(:run).and_wrap_original do |original|
            if values.empty?
              original.call
            else
              Foobara::Outcome.success(values.shift)
            end
          end
        end

        let(:maximum_call_count) { 50 }

        it "can retry", vcr: { record: :none } do
          expect {
            expect(outcome).to be_success
            expect(result[:result_data].name).to eq("Barbara")
          }.to change {
            Capybaras::Capybara.transaction do
              Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
            end
          }.from(19).to(2019)
        end
      end

      context "with no result type or response to user" do
        let(:result_type) { nil }
        let(:include_message_to_user_in_result) { false }

        it "can fix the busted record and fix it back", vcr: { record: :none } do
          expect {
            expect(outcome).to be_success
            expect(result).to eq(message_to_user: nil, result_data: nil)
          }.to change {
            Capybaras::Capybara.transaction do
              Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
            end
          }.from(19).to(2019)

          expect {
            new_outcome = agent.accomplish_goal(
              "Thank you so much! Can you set the value you changed back to what it was " \
              "so that I can demo how you can change it over again? Thanks!",
              result_type:
            )
            expect(new_outcome).to be_success
            expect(new_outcome.result).to eq(message_to_user: nil, result_data: nil)
          }.to change {
            Capybaras::Capybara.transaction do
              Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
            end
          }.from(2019).to(19)
        end
      end
    end

    describe "#kill!" do
      it "kills the agent" do
        expect {
          agent.kill!
        }.to change(agent, :killed?).from(false).to(true)
      end
    end
  end
end
