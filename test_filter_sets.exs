# Test script for filter sets
alias SelectoTest.{Repo, FilterSets}

# Clean up existing test data
Repo.delete_all(SelectoTest.FilterSets.FilterSet)

# Test creating a filter set
IO.puts("Testing filter set creation...")

attrs = %{
  name: "Test Filter Set",
  description: "A test filter set",
  domain: "pagila",
  filters: %{
    "actor_id" => %{"comp" => ">", "value" => "10", "filter" => "actor_id"},
    "first_name" => %{"comp" => "starts", "value" => "A", "filter" => "first_name"}
  },
  user_id: "test_user",
  is_shared: false,
  is_system: false
}

case FilterSets.create_filter_set(attrs) do
  {:ok, filter_set} ->
    IO.puts("✓ Filter set created successfully:")
    IO.inspect(filter_set, pretty: true)

    # Test listing personal filter sets
    IO.puts("\nTesting list_personal_filter_sets...")
    personal = FilterSets.list_personal_filter_sets("test_user", "pagila")
    IO.puts("✓ Found #{length(personal)} personal filter sets")

    # Test getting a specific filter set
    IO.puts("\nTesting get_filter_set...")

    case FilterSets.get_filter_set(filter_set.id, "test_user") do
      {:ok, retrieved} ->
        IO.puts("✓ Retrieved filter set: #{retrieved.name}")

      {:error, reason} ->
        IO.puts("✗ Failed to retrieve: #{reason}")
    end

    # Test updating
    IO.puts("\nTesting update_filter_set...")
    update_attrs = %{name: "Updated Filter Set", is_shared: true}

    case FilterSets.update_filter_set(filter_set.id, update_attrs, "test_user") do
      {:ok, updated} ->
        IO.puts("✓ Updated filter set: #{updated.name} (shared: #{updated.is_shared})")

      {:error, reason} ->
        IO.puts("✗ Failed to update: #{reason}")
    end

    # Test listing shared filter sets
    IO.puts("\nTesting list_shared_filter_sets...")
    shared = FilterSets.list_shared_filter_sets("test_user", "pagila")
    IO.puts("✓ Found #{length(shared)} shared filter sets")

  {:error, changeset} ->
    IO.puts("✗ Failed to create filter set:")
    IO.inspect(changeset.errors)
end

IO.puts("\n✓ All tests completed!")
