require "dotenv"

require "foobara/load_dotenv"

Dotenv.require_keys("FOOBARA_ENV")

env = ENV.fetch("FOOBARA_ENV", nil)

Foobara::LoadDotenv.run!(env:)
