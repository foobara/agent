RSpec.describe Foobara::Agent::AccomplishGoal do
  after do
    Foobara.reset_alls
    if Foobara::Agent.const_defined?(agent.agent_id)
      Foobara::Agent.send(:remove_const, agent.agent_id)
    end
  end

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  let(:outcome) do
    # This is awkward because AccomplishGoal doesn't quite function as a public interface to the
    # Agent domain. Not sure how or if to fix.
    agent.accomplish_goal(goal, result_type: final_result_type,
                                include_message_to_user_in_result:,
                                llm_model:)
  end
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }
  let(:agent) do
    Foobara::Agent.new(agent_name:, command_classes:, llm_model:)
  end
  let(:agent_name) { "CapybaraAgent" }
  let(:llm_model) { nil }
  let(:include_message_to_user_in_result) { true }

  context "when there are some capybaras but one has a bad year of birth" do
    use_capybaras_domain

    before do
      Capybaras::CreateCapybara.run!(name: "Fumiko", year_of_birth: 2020)
      Capybaras::CreateCapybara.run!(name: "Barbara", year_of_birth: 19)
      Capybaras::CreateCapybara.run!(name: "Basil", year_of_birth: 2021)
    end

    let(:final_result_type) { Capybaras::Capybara }
    let(:command_classes) { [Capybaras::FindAllCapybaras, Capybaras::UpdateCapybara] }
    let(:goal) do
      "There is a capybara with year of birth that was entered in the wrong format. " \
        "Find and fix the bad record."
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

    context "when result type is a model" do
      let(:final_result_type) do
        stub_class("Capybaras::CapybaraSummary", Foobara::Model) do
          attributes do
            name :string, :required
            old_year_of_birth :integer, :required
            new_year_of_birth :integer, :required
          end
        end
      end
      let(:include_message_to_user_in_result) { false }
      let(:verbose) { true }

      it "returns the data with the expected type", vcr: { record: :none } do
        expect {
          expect(outcome).to be_success
          summary = result[:result_data]
          expect(summary.name).to eq("Barbara")
          expect(summary.old_year_of_birth).to eq(19)
          expect(summary.new_year_of_birth).to eq(2019)
        }.to change {
          Capybaras::Capybara.transaction do
            Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
          end
        }.from(19).to(2019)
      end
    end

    context "when using openai" do
      let(:llm_model) { "gpt-4o" }

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

    context "when using ollama" do
      context "when using qwen3:14b" do
        let(:llm_model) { "qwen3:14b" }

        # This model needs some help or it sets the year to 2020 or 2022 instead of guessing 2019.
        let(:goal) do
          "There is a capybara with a bad year of birth. " \
            "It was entered as a 2-digit year on accident instead of a 4-digit year. " \
            "Can you find this record and prepend the mising \"20\"?"
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

      context "when using deepseek-r1:32b" do
        let(:llm_model) { "deepseek-r1:32b" }

        # This model sometimes needs help or it sets the year a random-ish year instead of 2019.
        let(:goal) do
          "There is a capybara with a bad year of birth. " \
            "It was entered as a 2-digit year on accident instead of a 4-digit year. " \
            "Find and fix the bad record by prepending the missing \"20\"."
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
  end
end
