# Test script to verify group_by_filter functionality
alias SelectoTest.Repo
import Ecto.Query

# Test that the group_by_filter configuration is working
IO.puts("Testing group_by_filter configuration...\n")

# First, let's see what the full_name column configuration looks like
domain = SelectoTest.PagilaDomain.actors_domain()
full_name_config = domain.custom_columns["full_name"]

IO.puts("Full Name Column Configuration:")
IO.inspect(full_name_config, pretty: true)
IO.puts("\n")

# Verify the group_by_filter is set to "actor_id"
if full_name_config.group_by_filter == "actor_id" do
  IO.puts("✓ group_by_filter is correctly set to 'actor_id'")
else
  IO.puts(
    "✗ group_by_filter is NOT set to 'actor_id': #{inspect(full_name_config.group_by_filter)}"
  )
end

# Verify the group_by_filter_select includes both fields
expected_select = ["full_name", "actor_id"]

if full_name_config.group_by_filter_select == expected_select do
  IO.puts("✓ group_by_filter_select correctly includes both fields: #{inspect(expected_select)}")
else
  IO.puts(
    "✗ group_by_filter_select does not match expected: #{inspect(full_name_config.group_by_filter_select)}"
  )
end

# Now let's test with actual data to see if actors with the same name would be kept separate
IO.puts("\n\nTesting with actual data...")

# Query to find actors and show their full names with IDs
query =
  from a in SelectoTest.Store.Actor,
    select: {fragment("concat(?, ' ', ?)", a.first_name, a.last_name), a.actor_id},
    order_by: [a.last_name, a.first_name],
    limit: 10

results = Repo.all(query)

IO.puts("Sample actors (full_name, actor_id):")

for {name, id} <- results do
  IO.puts("  #{name} (ID: #{id})")
end

# Check if there are any duplicate names
names = Enum.map(results, fn {name, _} -> name end)
unique_names = Enum.uniq(names)

if length(names) == length(unique_names) do
  IO.puts("\n✓ No duplicate names found in this sample")
else
  IO.puts("\n! Found duplicate names - these should remain separate in aggregate view:")
  duplicates = names -- unique_names

  for dup_name <- Enum.uniq(duplicates) do
    actors = Enum.filter(results, fn {name, _} -> name == dup_name end)

    IO.puts(
      "  '#{dup_name}' appears for actor IDs: #{inspect(Enum.map(actors, fn {_, id} -> id end))}"
    )
  end
end

IO.puts("\n✓ Configuration test completed!")
IO.puts("\nTo fully test the drill-down:")
IO.puts("1. Navigate to http://localhost:4000/pagila")
IO.puts("2. Switch to Aggregate view")
IO.puts("3. Group by 'Full Name'")
IO.puts("4. Click on any grouped name")
IO.puts("5. Verify the filter applied is 'actor_id = X' not 'full_name = Y'")
