import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
#
# The test database can be pointed elsewhere (for example a RAM-backed
# instance) with SELECTO_TEST_PG_URL, or with SELECTO_TEST_PG_HOST,
# SELECTO_TEST_PG_PORT, SELECTO_TEST_PG_USER, SELECTO_TEST_PG_PASSWORD and
# SELECTO_TEST_PG_DATABASE. Individual variables override the URL. Empty values
# count as unset, so a blank variable never falls back to a default socket.
test_pg_env = fn name ->
  case System.get_env(name) do
    value when value in [nil, ""] -> nil
    value -> value
  end
end

test_pg_url =
  case test_pg_env.("SELECTO_TEST_PG_URL") do
    nil -> %URI{}
    url -> URI.parse(url)
  end

{test_pg_url_user, test_pg_url_password} =
  case test_pg_url.userinfo do
    nil ->
      {nil, nil}

    userinfo ->
      case String.split(userinfo, ":", parts: 2) do
        [user, password] -> {URI.decode(user), URI.decode(password)}
        [user] -> {URI.decode(user), nil}
      end
  end

test_pg_url_database =
  case test_pg_url.path do
    path when path in [nil, "", "/"] -> nil
    path -> String.trim_leading(path, "/")
  end

config :selecto_test, SelectoTest.Repo,
  username: test_pg_env.("SELECTO_TEST_PG_USER") || test_pg_url_user || "postgres",
  password: test_pg_env.("SELECTO_TEST_PG_PASSWORD") || test_pg_url_password || "postgres",
  hostname: test_pg_env.("SELECTO_TEST_PG_HOST") || test_pg_url.host || "localhost",
  port:
    String.to_integer(test_pg_env.("SELECTO_TEST_PG_PORT") || to_string(test_pg_url.port || 5432)),
  database:
    test_pg_env.("SELECTO_TEST_PG_DATABASE") || test_pg_url_database ||
      "selecto_test_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  timeout: 120_000,
  ownership_timeout: 120_000

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :selecto_test, SelectoTestWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "22H/Bfx3qdytY6WVLgmK3/lGWRrKQO4YlHYC7tIoaN81MVS4P196XL0/qrHFn2L3",
  server: false

# In test we don't send emails.
config :selecto_test, SelectoTest.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Configure test coverage and performance
config :excoveralls, :minimum_coverage, 70

# Test timeout configuration
config :ex_unit,
  timeout: 120_000,
  capture_log: true

# Disable telemetry in tests for better performance
config :telemetry, :disable_default_handlers, true
