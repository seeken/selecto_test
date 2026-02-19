# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     SelectoTest.Repo.insert!(%SelectoTest.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Load Pagila sample data
pagila_data_file = Path.join([__DIR__, "..", "sql", "pagila-data.sql"])

if File.exists?(pagila_data_file) do
  IO.puts("Loading Pagila sample data...")

  # Get database config
  repo_config = SelectoTest.Repo.config()
  database = repo_config[:database]
  username = repo_config[:username] || "postgres"
  hostname = repo_config[:hostname] || "localhost"
  port = repo_config[:port] || 5432

  # Use psql to execute the data file (contains COPY statements)
  psql_cmd =
    ~s(PGPASSWORD="#{repo_config[:password]}" psql -h #{hostname} -p #{port} -U #{username} -d #{database} -f #{pagila_data_file})

  case System.cmd("sh", ["-c", psql_cmd], stderr_to_stdout: true) do
    {_output, 0} ->
      IO.puts("✓ Pagila sample data loaded successfully")

    {output, exit_code} ->
      IO.puts("⚠ Error loading Pagila data (exit code: #{exit_code})")

      if String.contains?(output, "psql: command not found") do
        IO.puts("psql command not found - skipping Pagila data loading")
      else
        IO.puts("Output: #{String.slice(output, 0, 500)}...")
      end
  end
else
  IO.puts("⚠ Pagila data file not found at #{pagila_data_file}")
end

# Initialize other seeds
SelectoTest.Seed.init()
