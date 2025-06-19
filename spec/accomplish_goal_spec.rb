RSpec.describe Foobara::Agent::AccomplishGoal do
  after { Foobara.reset_alls }

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  let(:command) { described_class.new(inputs) }
  let(:outcome) { command.run }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }

  let(:inputs) do
    h = {
      goal:,
      agent_name: "CapybaraAgent",
      command_classes:,
      final_result_type:
    }

    if llm_model
      h[:llm_model] = llm_model
    end

    h
  end
  let(:llm_model) { nil }

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
      "There is a capybara with an incorrectly-entered year of birth. Can you find and fix the bad record?"
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
          "There is a capybara with a bad year of birth." \
            "It was entered as a 2-digit year on accident instead of a 4-digit year." \
            "Can you find this record and prepend the mising \"20\"? Thanks!"
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
