RSpec.describe Foobara::Agent do
  after { Foobara.reset_alls }

  before do
    Foobara::Persistence.default_crud_driver = Foobara::Persistence::CrudDrivers::InMemory.new
  end

  let(:agent) { described_class.new(agent_name:, command_classes:, llm_model:) }
  let(:result) { outcome.result }
  let(:errors) { outcome.errors }
  let(:errors_hash) { outcome.errors_hash }
  let(:agent_name) { "CapybaraAgent" }
  let(:llm_model) { "claude-3-7-sonnet-20250219" }

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
      let(:outcome) { agent.accomplish_goal(goal, result_type:) }

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

    describe "#run" do
      let(:io_in_pipe) { IO.pipe }
      let(:io_out_pipe) { IO.pipe }
      let(:io_in_reader) { io_in_pipe.first }
      let(:io_in_writer) { io_in_pipe.last }
      let(:io_out_reader) { io_out_pipe.first }
      let(:io_out_writer) { io_out_pipe.last }

      let(:io_in) { io_in_reader }
      let(:io_out) { io_out_writer }

      def next_message_to_user
        response = io_out_reader.readline.chomp

        if response =~ /\A[\s>]*\z/
          next_message_to_user
        else
          response
        end
      end

      it "can handle new goals with old context", vcr: { record: :none } do
        agent_thread = nil

        begin
          agent_thread = Thread.new do
            agent.run(io_in:, io_out:)
          ensure
            io_in_writer.close
            io_out_writer.close
          end

          Capybaras::Capybara.transaction do
            expect(Capybaras::Capybara.find_by(name: "Barbara").year_of_birth).to eq(19)
          end

          io_in_writer.puts goal

          response = next_message_to_user
          expect(response).to be_a(String)

          Capybaras::Capybara.transaction do
            expect(Capybaras::Capybara.find_by(name: "Barbara").year_of_birth).to eq(2019)
          end

          io_in_writer.puts "Thank you so much! Can you set it back so that I can do the demo over again? Thanks!"

          response = next_message_to_user
          expect(response).to be_a(String)

          Capybaras::Capybara.transaction do
            expect(Capybaras::Capybara.find_by(name: "Barbara").year_of_birth).to eq(19)
          end
        ensure
          io_in_writer.close
          io_out_writer.close

          agent_thread&.join
        end
      end

      context "when using openai" do
        let(:llm_model) { "chatgpt-4o-latest" }

        it "can handle new goals with old context using openai models", vcr: { record: :none } do
          agent_thread = nil

          begin
            agent_thread = Thread.new do
              agent.run(io_in:, io_out:)
            ensure
              io_in_writer.close
              io_out_writer.close
            end

            Capybaras::Capybara.transaction do
              expect(Capybaras::Capybara.find_by(name: "Barbara").year_of_birth).to eq(19)
            end

            io_in_writer.puts goal

            response = next_message_to_user
            expect(response).to be_a(String)

            Capybaras::Capybara.transaction do
              expect(Capybaras::Capybara.find_by(name: "Barbara").year_of_birth).to eq(2019)
            end

            io_in_writer.puts "Thank you so much! Can you set it back so that I can do the demo over again? Thanks!"

            response = next_message_to_user
            expect(response).to be_a(String)

            Capybaras::Capybara.transaction do
              expect(Capybaras::Capybara.find_by(name: "Barbara").year_of_birth).to eq(19)
            end
          ensure
            io_in_writer.close
            io_out_writer.close

            agent_thread&.join
          end
        end
      end
    end
  end
end
