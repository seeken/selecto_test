# Test script to check how Selecto.field handles custom columns
alias SelectoTest.PagilaDomain

# Get the domain configuration
domain = PagilaDomain.actors_domain()

# Create a mock selecto struct with the domain
selecto = %{
  domain: domain,
  custom_columns: domain.custom_columns
}

# Try to look up the full_name field
IO.puts("Testing Selecto.field lookup for custom column 'full_name'...")

# The field might be passed as different formats
test_formats = [
  :full_name,
  "full_name",
  {:field, :full_name, "Full Name"},
  {:field, "full_name", "Full Name"}
]

for format <- test_formats do
  IO.puts("\nTrying format: #{inspect(format)}")

  field_id =
    case format do
      {:field, id, _alias} -> id
      other -> other
    end

  result =
    try do
      Selecto.field(selecto, field_id)
    rescue
      e -> "Error: #{inspect(e)}"
    end

  IO.inspect(result, pretty: true, limit: :infinity)
end

IO.puts("\n\nDirect access to custom_columns:")
IO.inspect(domain.custom_columns["full_name"], pretty: true)
