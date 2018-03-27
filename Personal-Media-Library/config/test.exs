use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :media_library, MediaLibraryWeb.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :media_library, :db, name: "mongo_test"