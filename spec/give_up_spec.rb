RSpec.describe Foobara::Agent::GiveUp do
  after { Foobara.reset_alls }

  let(:agent) do
    Foobara::Agent.new(
      agent_name:,
      command_classes:
    )
  end
  let(:agent_name) { "CapybaraAgent" }
  let(:command_classes) { [] }

  let(:accomplish_goal) { Foobara::Agent::AccomplishGoal.new(inputs) }
  let(:outcome) { accomplish_goal.run }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }

  let(:inputs) do
    {
      goal:,
      agent:
    }
  end

  let(:goal) do
    "Hi! I am trying to test what happens when you run the GiveUp command. Can you choose it, please? Thanks!"
  end

  it "gives up and gives an expected error as a result", :focus, vcr: { record: :none } do
    expect(outcome).to_not be_success
    binding.pry
    expect(errors_hash.keys).to eq(["runtime.gave_up"])
  end
end
