#!/usr/bin/env elixir

# Test script to verify actor_card custom column works with IOData

alias SelectoTest.PagilaDomain
alias SelectoTest.Repo

# Get the domain configuration
domain_config = PagilaDomain.actors_domain()

# Test getting the actor_card column configuration
actor_card_config = domain_config.config.custom_columns["actor_card"]
IO.puts("Actor Card Config:")
IO.inspect(actor_card_config, pretty: true)

# Test the requires_select function with a limit configuration
config = %{"limit" => 3}
requires_select = actor_card_config.requires_select.(config)
IO.puts("\nRequires Select (with limit=3):")
IO.inspect(requires_select, pretty: true)

# Test building a query with the actor_card column
selecto =
  Selecto.configure(
    conn: Repo.config()[:database],
    config: domain_config.config
  )

# Select actor_card along with basic fields
selecto = Selecto.select(selecto, ["actor_id", "first_name", "last_name", "actor_card[limit:3]"])

# Generate the SQL to see if the IOData parameter works
case Selecto.to_sql(selecto) do
  {:ok, sql, params} ->
    IO.puts("\n✅ SQL Generated Successfully:")
    IO.puts(sql)
    IO.puts("\nParameters:")
    IO.inspect(params, pretty: true)

    # Try to execute the query
    case Selecto.execute(selecto) do
      {:ok, results} ->
        IO.puts("\n✅ Query Executed Successfully!")
        IO.puts("First row:")
        IO.inspect(List.first(results), pretty: true)

      {:error, error} ->
        IO.puts("\n❌ Query Execution Error:")
        IO.inspect(error, pretty: true)
    end

  {:error, error} ->
    IO.puts("\n❌ SQL Generation Error:")
    IO.inspect(error, pretty: true)
end
