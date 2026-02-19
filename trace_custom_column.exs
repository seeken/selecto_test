#!/usr/bin/env elixir

alias SelectoTest.PagilaDomain

# 1. Get initial domain
domain = PagilaDomain.actors_domain()
IO.puts("\n1. Initial domain custom_columns:")
IO.inspect(Map.keys(domain.custom_columns), label: "Keys")
full_name_col = domain.custom_columns["full_name"]
IO.inspect(full_name_col, label: "full_name column", limit: :infinity)

# 2. Configure Selecto
{:ok, conn} =
  Postgrex.start_link(
    hostname: "localhost",
    username: "postgres",
    password: "postgres",
    database: "selecto_test_dev"
  )

repo = Selecto.configure(domain, conn: conn)

# 3. Call Selecto.field (what aggregate component does)
IO.puts("\n2. Selecto.field result:")
field_result = Selecto.field(repo, :full_name)
IO.inspect(field_result, label: "Selecto.field(:full_name)", limit: :infinity)

IO.puts("\n3. Checking group_by_filter presence:")
IO.puts("Has :group_by_filter? #{Map.has_key?(field_result || %{}, :group_by_filter)}")
IO.puts("Has \"group_by_filter\"? #{Map.has_key?(field_result || %{}, "group_by_filter")}")

if field_result do
  IO.puts(
    "Value: #{inspect(Map.get(field_result, :group_by_filter) || Map.get(field_result, "group_by_filter"))}"
  )
end

# 4. Check what field tuple would be created
field_tuple = {:field, :full_name, "Full Name"}
IO.puts("\n4. Field tuple that would be created:")
IO.inspect(field_tuple)

# 5. Check final group_by structure
group_by_item = {"Full Name", {:group_by, field_tuple, field_result}}
IO.puts("\n5. Group by item structure:")
IO.inspect(group_by_item, limit: :infinity)
