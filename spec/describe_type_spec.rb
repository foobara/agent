RSpec.describe Foobara::Agent::DescribeType do
  after { Foobara.reset_alls }

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  let(:agent) do
    Foobara::Agent.new(agent_name:, command_classes:)
  end
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }
  let(:agent_name) { "CapybaraAgent" }

  context "when using the capybaras domain" do
    use_capybaras_domain

    let(:command_classes) { [Capybaras::FindAllCapybaras, Capybaras::UpdateCapybara] }

    describe ".command_connector.run to run DescribeType" do
      let(:response) do
        agent.run(
          full_command_name: described_class.full_command_name,
          inputs: { type_name: "Capybaras::Capybara" },
          action: "run"
        )
      end
      let(:outcome) { response.outcome }

      it "can fix the busted record", :focus do
        expect(outcome).to be_success
        expect(result[:json_schema]).to match(/rodent/i)
      end
    end
  end
end
