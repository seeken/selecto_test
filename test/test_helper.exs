# Configure test environment
Application.put_env(:ex_unit, :capture_log, true)

# Determine which tests to exclude
exclude_tags =
  if System.get_env("TEST_MYSQL") do
    [:skip, :pending]
  else
    [:skip, :pending, :mysql_integration]
  end

# Increase timeout and allow parallelization while maintaining stability
ExUnit.start(
  timeout: 120_000,
  max_cases: System.schedulers_online(),
  capture_log: true,
  exclude: exclude_tags
)

Ecto.Adapters.SQL.Sandbox.mode(SelectoTest.Repo, :manual)
