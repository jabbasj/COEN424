# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration

# Configures the endpoint
config :media_library, MediaLibraryWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "h08yW7C47gvyOSyi3UAfalE+LzL0orhW7RM2gZQZ+YFTzWWW7C4yl8CqHFs4f96H",
  render_errors: [view: MediaLibraryWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: MediaLibrary.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

#oauth2 already pre-configured to use Poison for JSON
config :oauth2, debug: true

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"

########################################
## Database and storage configuration ##
########################################

# Local configuration
# config :media_library, :db, name: :mongo, database: "mongo_test"

# Cloud configuration
config :media_library, :db, 
name: :mongo,
database: "media_library",
seeds: [
  "personal-media-library-shard-00-00-t6ofa.mongodb.net:27017",
  "personal-media-library-shard-00-01-t6ofa.mongodb.net:27017",
  "personal-media-library-shard-00-02-t6ofa.mongodb.net:27017"
],
set_name: "Personal-Media-Library-shard-0",
username: "admin",
password: "coen424",
auth_source: "admin",
port: 27017,
type: :replica_set_no_primary,
ssl: true

# Storage mode (:local or :s3) and directory
config :media_library, 
storage_mode: :s3,
upload_dir: "./tmp/uploads/"

# AWS configuration

config :ex_aws,
access_key_id: "AKIAJ4YKUVYRUZ6U3XOA",
secret_access_key: "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"

config :media_library, 
s3_url: "https://s3.amazonaws.com/",
s3_bucket: "pml-storage"
