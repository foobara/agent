RSpec.describe Foobara::Agent do
  after { Foobara.reset_alls }

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  let(:agent) do
    described_class.new(
      agent_name:,
      command_classes:,
      llm_model:
    )
  end
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }
  let(:agent_name) { "CapybaraAgent" }
  let(:llm_model) { "claude-3-7-sonnet-20250219" }
  let(:choose_next_command_and_next_inputs_separately) { false }

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
        agent.accomplish_goal(goal, result_type:,
                                    choose_next_command_and_next_inputs_separately:)
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
            result_type:,
            choose_next_command_and_next_inputs_separately:
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

      context "when choosing next command and next inputs separately" do
        let(:llm_model) { "gpt-4o" }

        # For some reason this needs some help or it sets the year to 2020 or 2022 instead of guessing 2019.
        let(:goal) {
          "There is a capybara with a bad year of birth." \
            "It was entered as a 2-digit year on accident instead of a 4-digit year." \
            "Can you find this record and prepend the mising \"20\"? Thanks!"
        }

        let(:choose_next_command_and_next_inputs_separately) { true }

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
              "Thank you so much! Can you set the value you changed back to what it was " \
              "so that I can demo how you can change it over again? Thanks!",
              result_type:,
              choose_next_command_and_next_inputs_separately:
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
      end
    end
  end
end
