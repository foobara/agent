RSpec.describe Foobara::Agent::AccomplishGoal do
  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  let(:command) { described_class.new(inputs) }
  let(:outcome) { command.run }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }

  let(:inputs) do
    {
      goal:,
      agent_name: "CapybaraAgent",
      command_classes:,
      final_result_type:
    }
  end

  context "when there are some capybaras but one has a bad year of birth" do
    require_relative "fixtures/capybaras_domain"

    before do
      Capybaras::CreateCapybara.run!(name: "Fumiko", year_of_birth: 2020)
      Capybaras::CreateCapybara.run!(name: "Barbara", year_of_birth: 19)
      Capybaras::CreateCapybara.run!(name: "Basil", year_of_birth: 2021)
    end

    let(:final_result_type) { Capybaras::Capybara }
    let(:command_classes) { [Capybaras::FindAllCapybaras, Capybaras::UpdateCapybara] }
    let(:goal) { "There is a capybara with a bad year of birth. Can you find and fix the bad record? Thanks!" }

    it "can fix the busted record", :focus, vcr: { record: :none } do
      binding.pry
      expect {
        expect(outcome).to be_success
        expect(result.name).to eq("Barbara")
      }.to change {
        Capybaras::Capybara.transaction do
          Capybaras::Capybara.find_by(name: "Barbara").year_of_birth
        end
      }.from(19).to(2019)
    end
  end
end
