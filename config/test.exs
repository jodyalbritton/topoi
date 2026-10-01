import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :topoi, Topoi.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "topoi_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :topoi, TopoiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "9dHGkH21u0uWb9LZFRJZfB3zVKBCJVYLmh+4MZTtNGYElN/0pW9Tqp7nGgS2aJ9g",
  server: false

# In test we don't send emails
config :topoi, Topoi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Oban jobs are enqueued but not run; tests drive them with Oban.Testing.
config :topoi, Oban, testing: :manual

# Static test key for encrypted columns. Not a secret.
config :topoi, Topoi.Vault,
  ciphers: [
    default:
      {Cloak.Ciphers.AES.GCM,
       tag: "AES.GCM.V1",
       key: Base.decode64!("dGVzdC1rZXktdGVzdC1rZXktdGVzdC1rZXktdGVzdCE="),
       iv_length: 12}
  ]

# External HTTP goes to Req.Test stubs in tests; no network.
config :topoi, Topoi.Transcripts.ElevenLabs,
  req_options: [plug: {Req.Test, Topoi.Transcripts.ElevenLabs}]

config :topoi, Topoi.Metadata, req_options: [plug: {Req.Test, Topoi.Metadata}]

config :topoi, Topoi.Ingest.Canonicalize,
  req_options: [plug: {Req.Test, Topoi.Ingest.Canonicalize}]

config :topoi, Topoi.AI.Gateway, req_options: [plug: {Req.Test, Topoi.AI.Gateway}]
