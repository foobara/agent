RSpec.describe Foobara::Agent do
  after { Foobara.reset_alls }

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  let(:agent) { described_class.new(agent_name:, command_classes:) }
  let(:outcome) { agent.accomplish_goal(goal, result_type:) }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }
  let(:agent_name) { "CapybaraAgent" }

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

    it "can fix the busted record", vcr: { record: :none } do
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
