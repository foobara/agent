module CapybarasDomainStubs
  module ClassMethods
    def use_capybaras_domain
      before do
        use_capybaras_domain
      end
    end
  end

  define_method :use_capybaras_domain do
    stub_module(:Capybaras) { foobara_domain! }

    stub_class("Capybaras::Capybara", Foobara::Entity) do
      description "A gigantic semi-aquatic rodent!"

      attributes do
        id :integer
        name :string, :required, "Name of the Capybara"
        year_of_birth :integer, :required, "The year the Capybara was born"
      end

      primary_key :id
    end

    stub_class("Capybaras::CreateCapybara", Foobara::Command) do
      description "Creates a Capybara record"

      inputs Capybaras::Capybara.attributes_for_create
      result Capybaras::Capybara, description: "The freshly created Capybara record"

      def execute
        create_capybara

        capybara
      end

      attr_accessor :capybara

      def create_capybara
        self.capybara = Capybaras::Capybara.create(inputs)
      end
    end

    stub_class("Capybaras::UpdateCapybara", Foobara::Command) do
      description "Updates a Capybara record"

      inputs Capybaras::Capybara.attributes_for_update
      result Capybaras::Capybara, description: "The updated Capybara record"

      def execute
        load_capybara
        update_capybara

        capybara
      end

      attr_accessor :capybara

      def load_capybara
        self.capybara = Capybaras::Capybara.load(id)
      end

      def update_capybara
        capybara.update(inputs)
      end
    end

    stub_class("Capybaras::FindAllCapybaras", Foobara::Command) do
      description "Returns all Capybara records"

      result [Capybaras::Capybara], description: "All of the Capybara records there are!"

      def execute
        find_all_capybaras
      end

      def find_all_capybaras
        Capybaras::Capybara.all
      end
    end
  end
end

RSpec.configure do |c|
  c.extend CapybarasDomainStubs::ClassMethods
  c.include CapybarasDomainStubs
end
