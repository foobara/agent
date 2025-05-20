RSpec.describe Foobara::Agent::GiveUp do
  after { Foobara.reset_alls }

  let(:accomplish_goal) { Foobara::Agent::AccomplishGoal.new(inputs) }
  let(:outcome) { accomplish_goal.run }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }

  let(:inputs) do
    { goal:, agent_name: "CapybaraAgent", command_classes: [] }
  end

  let(:goal) do
    "Hi! I am trying to test what happens when you run the GiveUp command. Can you choose it, please? Thanks!"
  end

  it "gives up and gives an expected error as a result", vcr: { record: :none } do
    expect(outcome).to_not be_success
    expect(errors_hash.keys).to eq(["runtime.gave_up"])
  end
end
