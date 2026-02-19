#!/usr/bin/env elixir

# Test script to verify drill-down functionality with actor_id filter

alias SelectoTest.PagilaDomain
alias SelectoTest.Repo

# Get the actor domain configuration
domain = PagilaDomain.actors_domain()

# Check the custom column configuration
IO.puts("Custom column 'full_name' configuration:")
custom_col = domain.custom_columns["full_name"]
IO.inspect(custom_col, limit: :infinity)

IO.puts("\nFields that should be included:")
IO.puts("- group_by_filter: #{Map.get(custom_col, :group_by_filter)}")
IO.puts("- group_by_filter_select: #{inspect(Map.get(custom_col, :group_by_filter_select))}")

# Now test Selecto.field to see what it returns
IO.puts("\n\nTesting Selecto.field with custom column:")
# Create a proper Postgrex connection
{:ok, conn} =
  Postgrex.start_link(
    hostname: "localhost",
    username: "postgres",
    password: "postgres",
    database: "selecto_test_dev"
  )

repo = Selecto.configure(domain, conn: conn)

field_info = Selecto.field(repo, "full_name")
IO.puts("Result from Selecto.field('full_name'):")
IO.inspect(field_info, limit: :infinity)

IO.puts("\nVerifying drill-down properties are preserved:")
IO.puts("- group_by_filter: #{Map.get(field_info, :group_by_filter)}")
IO.puts("- group_by_filter_select: #{inspect(Map.get(field_info, :group_by_filter_select))}")

# Now test an aggregate query with the custom column
IO.puts("\n\nTesting aggregate query with full_name:")

query =
  repo
  |> Selecto.group_by(["full_name", "actor_id"])
  |> Selecto.select(["full_name", "actor_id", {:count, "actor_id"}])
  |> Selecto.limit(5)

{sql, params} = Selecto.to_sql(query)
IO.puts("Generated SQL:")
IO.puts(sql)
IO.puts("\nParameters: #{inspect(params)}")

# Execute the query
case Selecto.execute(query) do
  {:ok, results} ->
    IO.puts("\nQuery results (first 5 actors):")

    for row <- results do
      IO.puts("  #{row["full_name"]} - Count: #{row["count"]}")
    end

  {:error, error} ->
    IO.puts("\nError executing query:")
    IO.inspect(error)
end

IO.puts("\n✓ Test complete")
