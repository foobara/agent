require "foobara/local_files_crud_driver"

crud_driver = Foobara::LocalFilesCrudDriver.new(multi_process: true)
Foobara::Persistence.default_crud_driver = crud_driver

class Capybara < Foobara::Entity
  description "A gigantic semi-aquatic rodent!"

  attributes do
    id :integer
    name :string, :required, "Name of the Capybara"
    year_of_birth :integer, :required, "The year the Capybara was born"
  end

  primary_key :id
end

class CreateCapybara < Foobara::Command
  description "Creates a Capybara record"

  inputs Capybara.attributes_for_create
  result Capybara, description: "The freshly created Capybara record"

  def execute
    create_capybara

    capybara
  end

  attr_accessor :capybara

  def create_capybara
    self.capybara = Capybara.create(inputs)
  end
end

class UpdateCapybara < Foobara::Command
  description "Updates a Capybara record"

  inputs Capybara.attributes_for_update
  result Capybara, description: "The updated Capybara record"

  def execute
    load_capybara
    update_capybara

    capybara
  end

  attr_accessor :capybara

  def load_capybara
    self.capybara = Capybara.load(id)
  end

  def update_capybara
    capybara.update(inputs)
  end
end

class FindAllCapybaras < Foobara::Command
  description "Returns all Capybara records"

  result [Capybara], description: "All of the Capybara records there are!"

  def execute
    find_all_capybaras
  end

  def find_all_capybaras
    Capybara.all
  end
end

class DeleteAllCapybaras < Foobara::Command
  description "Deletes all Capybara records"

  depends_on_entity Capybara

  def execute
    delete_all
    nil
  end

  def delete_all
    FindAllCapybaras.run!.each(&:hard_delete!)
  end
end
