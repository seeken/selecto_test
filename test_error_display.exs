#!/usr/bin/env elixir

# Test script to trigger various types of errors to see the error display

alias SelectoTest.PagilaDomain
alias SelectoTest.Repo

IO.puts("Testing Error Display Scenarios...")
IO.puts("=" <> String.duplicate("=", 50))

# Get the domain configuration
domain_config = PagilaDomain.actors_domain()

# Configure Selecto
selecto =
  Selecto.configure(
    conn: Repo.config()[:database],
    config: domain_config.config
  )

# Test 1: Try to select a non-existent column
IO.puts("\n1. Testing non-existent column error:")
IO.puts("-" <> String.duplicate("-", 40))
selecto_bad_column = Selecto.select(selecto, ["first_name", "last_name", "non_existent_column"])

case Selecto.execute(selecto_bad_column) do
  {:ok, _results} ->
    IO.puts("❌ Unexpectedly succeeded")

  {:error, error} ->
    IO.puts("✅ Got expected error:")
    IO.inspect(error, pretty: true)
end

# Test 2: Try to use invalid SQL in a custom column
IO.puts("\n2. Testing SQL syntax error:")
IO.puts("-" <> String.duplicate("-", 40))

selecto_bad_sql =
  selecto
  |> Selecto.select(["first_name", "last_name"])
  |> Selecto.where({"first_name", {:raw, "INVALID SQL SYNTAX HERE)))"}})

case Selecto.execute(selecto_bad_sql) do
  {:ok, _results} ->
    IO.puts("❌ Unexpectedly succeeded")

  {:error, error} ->
    IO.puts("✅ Got expected error:")
    IO.inspect(error, pretty: true)
end

# Test 3: Try to reference an invalid join
IO.puts("\n3. Testing invalid join reference:")
IO.puts("-" <> String.duplicate("-", 40))
selecto_bad_join = Selecto.select(selecto, ["first_name", "invalid_join[field_name]"])

case Selecto.execute(selecto_bad_join) do
  {:ok, _results} ->
    IO.puts("❌ Unexpectedly succeeded")

  {:error, error} ->
    IO.puts("✅ Got expected error:")
    IO.inspect(error, pretty: true)
end

# Test 4: Try division by zero
IO.puts("\n4. Testing division by zero:")
IO.puts("-" <> String.duplicate("-", 40))

selecto_div_zero =
  selecto
  |> Selecto.select([{:divide, ["actor_id", 0]}])

case Selecto.execute(selecto_div_zero) do
  {:ok, _results} ->
    IO.puts("❌ Unexpectedly succeeded")

  {:error, error} ->
    IO.puts("✅ Got expected error:")
    IO.inspect(error, pretty: true)
end

IO.puts("\n" <> String.duplicate("=", 50))
IO.puts("Error testing complete!")
