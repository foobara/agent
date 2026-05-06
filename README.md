# Foobara::Agent

WARNING!! This agent will just run whatever command it thinks it should run without asking!

Accepts a list of Foobara commands and can then repeatedly accomplish goals you give it using those commands.

If you want a cli tool that wraps this gem, checkout foobara-agent-cli

Works with Ollama, Anthropic, or OpenAI models

## Contributing

I would love help with this and other Foobara gems! Feel free to hit me up at miles@foobara.org if you
think helping out would be fun or interesting! I have tasks for all experience levels and am often free
to pair on Foobara stuff.

Bug reports and pull requests are welcome on GitHub at https://github.com/foobara/agent

## Installation

Typical stuff: add `gem "foobara-agent"` to your Gemfile or .gemspec file. Or even just
`gem install foobara-agent` if that's your jam.

## Usage

Let's say we had a Capybaras domain with CreateCapybara, DeleteCapybara, UpdateCapybara, FindAllCapyaras commands.

See ./example_scripts/capybaras.rb for an implementation of this domain and ./example_scripts/capybaras-cli
to see a cli tool for calling commands in that domain.

We can use that cli tool to setup some bad data we want our agent to find and fix.

```
$ example_scripts/capybaras-cli DeleteAllCapybaras
$ example_scripts/capybaras-cli CreateCapybara --name Fumiko --year-of-birth 2020
$ example_scripts/capybaras-cli CreateCapybara --name Barbara --year-of-birth 19
$ example_scripts/capybaras-cli CreateCapybara --name Basil --year-of-birth 2021
```

We can see our records with:

```
$ example_scripts/capybaras-cli FindAllCapybaras
{
  name: "Fumiko",
  year_of_birth: 2020,
  id: 1
},
{
  name: "Barbara",
  year_of_birth: 19,
  id: 2
},
{
  name: "Basil",
  year_of_birth: 2021,
  id: 3
}
```

Notice how Barbara's record accidentally got a 2-digit year instead of a 4-digit year. Let's create an
agent and tell it to fix that!

We can create an agent like this:

```ruby
require "foobara/agent"

capy_agent = Foobara::Agent.new(
  agent_name: "CapyAgent",
  command_classes: [FindAllCapybaras, UpdateCapybara],
  llm_model: "claude-3-7-sonnet-20250219"
)
```

And now let's ask our agent to find and fix the bad record:

```ruby
capy_agent.accomplish_goal(
  "There is a capybara with a bad year of birth. Can you find and fix the bad record? Thanks!"
)
puts outcome.result[:message_to_user]
```

This code outputs:

```
I found and fixed the capybara with an invalid year of birth. Barbara had a year of birth of 19,
which is not realistic for a capybara. I updated her record to have a birth year of 2019,
which is more appropriate. The record has been successfully updated.
```

We can check with FindAllCapybaras that it actually fixed the record!

Let's tell our agent to set it back (in the same session):

```ruby
outcome = capy_agent.accomplish_goal(
  "Thank you so much! Can you set it back so that I can do the demo over again? Thanks!"
)
puts outcome.result[:message_to_user]
```

Running this code outputs:

```
I've reset Barbara's year of birth back to 19, so you can run the demo again.
The system is now ready for you to demonstrate the process of finding and fixing the invalid capybara data.
```

Please see example_scripts/capybaras_agent_script.rb for a working script that does this.

## License

This project is licensed under the MPL-2.0 license. Please see LICENSE.txt for more info.
