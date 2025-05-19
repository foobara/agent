RSpec.describe Foobara::Agent::AccomplishGoal do
  let(:command) { described_class.new(inputs) }
  let(:outcome) { command.run }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }

  let(:inputs) do
    { foo: "bar" }
  end

  it "is successful" do
    expect(outcome).to be_success
    expect(result).to eq("bar")
  end
end
