# Test script to verify Selecto telemetry events are being emitted

# Attach a handler to listen for Selecto events
:telemetry.attach(
  "test-selecto-handler",
  [:selecto, :query, :complete],
  fn event, measurements, metadata, _config ->
    IO.puts("\n🎉 Selecto telemetry event received!")
    IO.puts("Event: #{inspect(event)}")
    IO.puts("Measurements: #{inspect(measurements)}")
    IO.puts("Metadata keys: #{inspect(Map.keys(metadata))}")
  end,
  nil
)

IO.puts("Telemetry handler attached. Now testing Selecto query...\n")

# Test with a simple Selecto query
alias SelectoTest.PagilaDomain
alias SelectoTest.Repo

# PagilaDomain.actors_domain() returns the domain config
domain_config = PagilaDomain.actors_domain()

selecto =
  Selecto.configure(domain_config, Repo)
  |> Selecto.select(["actor_id", "first_name", "last_name"])
  |> Selecto.limit(1)

case Selecto.execute(selecto) do
  {:ok, {rows, _columns, _aliases}} ->
    IO.puts("\n✅ Query executed successfully!")
    IO.puts("Returned #{length(rows)} row(s)")

  {:error, error} ->
    IO.puts("\n❌ Query failed: #{inspect(error)}")
end

# Check if any handlers are attached to the selecto events
IO.puts("\nChecking telemetry handlers...")
handlers = :telemetry.list_handlers([:selecto, :query, :complete])
IO.puts("Handlers for [:selecto, :query, :complete]: #{length(handlers)}")

Enum.each(handlers, fn h ->
  IO.puts("  - #{h.id}")
end)

# Detach our test handler
:telemetry.detach("test-selecto-handler")
