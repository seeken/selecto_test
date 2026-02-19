#!/usr/bin/env elixir

# Test to trace how coldef flows through the aggregate component

alias SelectoTest.PagilaDomain

# Get the actor domain configuration
domain = PagilaDomain.actors_domain()

# Simulate what happens in render_synchronized_view

# 1. Field gets retrieved with Selecto.field
IO.puts("\n1. Getting field definition from domain:")
custom_col = domain.custom_columns["full_name"]
IO.inspect(custom_col, label: "Custom column from domain", limit: :infinity)

# 2. Simulate what happens when building group_by in line 391-419
IO.puts("\n2. Building group_by tuple:")
field = {:field, :full_name, "Full Name"}
alias_name = "Full Name"

# This simulates what Selecto.field would return
# In reality, Selecto.field returns this
coldef = custom_col

group_by_tuple = {alias_name, {:group_by, field, coldef}}
IO.inspect(group_by_tuple, label: "group_by tuple", limit: :infinity)

# 3. Simulate what gets passed to tree_table as groups
groups = [group_by_tuple]
IO.puts("\n3. Groups passed to tree_table:")
IO.inspect(groups, label: "groups", limit: :infinity)

# 4. Simulate payload building in tree_table (line 72-74)
IO.puts("\n4. Building payload in tree_table:")
i = 0
first_group = List.first(groups)
# This would be actual group value from results
gb = "Some Name"
payload_item = {i, first_group, gb, 0}
IO.inspect(payload_item, label: "payload item", limit: :infinity)

# 5. Simulate unpacking in the reduce function (line 134)
IO.puts("\n5. Unpacking in reduce function:")
{i, {_, {:group_by, _, coldef}}, v, _} = payload_item
IO.puts("Extracted coldef:")
IO.inspect(coldef, label: "coldef from payload", limit: :infinity)

# 6. Check if group_by_filter is present
IO.puts("\n6. Checking group_by_filter:")
filter_key = Map.get(coldef, :group_by_filter) || Map.get(coldef, "group_by_filter")
IO.puts("filter_key: #{inspect(filter_key)}")

if filter_key do
  IO.puts("✓ group_by_filter is preserved: #{filter_key}")
else
  IO.puts("✗ group_by_filter is missing!")
end
