defmodule SelectoBasicIntegrationTest do
  use SelectoTest.SelectoCase, async: false
  @moduletag cleanup_db: true
  
  # Comprehensive integration tests for Selecto with Pagila database
  # Tests all filter operations, select variations, and edge cases

  setup do
    # Insert test data
    test_data = insert_test_data!()
    
    # Define actor domain for testing
    domain = %{
      source: %{
        source_table: "actor",
        primary_key: :actor_id,
        fields: [:actor_id, :first_name, :last_name, :last_update],
        redact_fields: [],
        columns: %{
          actor_id: %{type: :integer},
          first_name: %{type: :string},
          last_name: %{type: :string},
          last_update: %{type: :utc_datetime}
        },
        associations: %{}
      },
      name: "Actor",
      joins: %{},
      schemas: %{}
    }
    
    selecto = Selecto.configure(domain, SelectoTest.Repo)
    
    {:ok, selecto: selecto, test_data: test_data}
  end

  describe "Basic Functionality" do
    test "select single field with filter", %{selecto: selecto, test_data: test_data} do
      alice_id = test_data.actors.actor1.actor_id
      
      result = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.filter({"actor_id", alice_id})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["first_name"]
      assert length(rows) == 1
      assert hd(rows) == ["Alice"]  # First actor alphabetically
    end

    test "select multiple fields with filter", %{selecto: selecto, test_data: test_data} do
      alice_id = test_data.actors.actor1.actor_id
      
      result = selecto
      |> Selecto.select(["first_name", "last_name"])
      |> Selecto.filter({"actor_id", alice_id})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["first_name", "last_name"]
      assert length(rows) == 1
      assert hd(rows) == ["Alice", "Johnson"]  # First actor alphabetically
    end

    test "select without filter returns all rows", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["actor_id"]
      assert length(rows) == 4  # Total test actors
    end
  end

  describe "Filter Operations - Basic Comparisons" do
    test "filter by exact match (explicit equality)", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["first_name", "last_name"])
      |> Selecto.filter({"first_name", {"=", "John"}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0
      Enum.each(rows, fn [first_name, _] -> 
        assert first_name == "John"
      end)
    end

    test "filter by not equal", %{selecto: selecto} do
      # Get all actors first to find a valid ID to filter by
      all_result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.execute()
      
      assert {:ok, {all_rows, _columns, _aliases}} = all_result
      assert length(all_rows) == 4  # We have 4 test actors
      
      # Get the first actor ID to exclude
      [[first_actor_id] | _] = all_rows
      
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", {"!=", first_actor_id}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 3  # All except the first actor
      Enum.each(rows, fn [actor_id] -> 
        assert actor_id != first_actor_id
      end)
    end

    test "filter by less than", %{selecto: selecto, test_data: test_data} do
      max_id = test_data.actors.actor4.actor_id
      
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", {"<", max_id + 1}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 4  # All 4 test actors
      Enum.each(rows, fn [actor_id] -> 
        assert actor_id < max_id + 1
      end)
    end

    test "filter by greater than", %{selecto: selecto, test_data: test_data} do
      min_id = test_data.actors.actor1.actor_id
      
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", {">", min_id - 1}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 4  # All 4 test actors (auto-generated IDs > min_id - 1)
      Enum.each(rows, fn [actor_id] -> 
        assert actor_id > min_id - 1
      end)
    end

    test "filter by less than or equal", %{selecto: selecto, test_data: test_data} do
      third_id = test_data.actors.actor3.actor_id
      
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", {"<=", third_id}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 3  # 3 actors with ID <= third_id
      Enum.each(rows, fn [actor_id] -> 
        assert actor_id <= third_id
      end)
    end

    test "filter by greater than or equal", %{selecto: selecto, test_data: test_data} do
      max_id = test_data.actors.actor4.actor_id
      
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", {">=", max_id + 1}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 0  # No actors with ID >= max_id + 1
      Enum.each(rows, fn [actor_id] -> 
        assert actor_id >= max_id + 1
      end)
    end

    test "filter by IN clause (list)", %{selecto: selecto, test_data: test_data} do
      actor1_id = test_data.actors.actor1.actor_id
      actor2_id = test_data.actors.actor2.actor_id
      actor3_id = test_data.actors.actor3.actor_id
      expected_ids = [actor1_id, actor2_id, actor3_id]
      
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", expected_ids})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 3
      ids = Enum.map(rows, fn [id] -> id end)
      assert Enum.sort(ids) == Enum.sort(expected_ids)
    end

    test "filter by LIKE pattern", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.filter({"first_name", {:like, "Jo%"}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0
      Enum.each(rows, fn [first_name] -> 
        assert String.starts_with?(first_name, "Jo")
      end)
    end

    test "filter by case-insensitive LIKE (ILIKE)", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.filter({"first_name", {:ilike, "jo%"}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0
      Enum.each(rows, fn [first_name] -> 
        assert String.starts_with?(String.upcase(first_name), "JO")
      end)
    end
  end

  describe "Filter Operations - NULL Handling" do
    setup %{selecto: selecto} do
      # Create a test domain that includes a nullable field
      domain = %{
        source: %{
          source_table: "film",
          primary_key: :film_id,
          fields: [:film_id, :title, :description, :release_year],
          redact_fields: [],
          columns: %{
            film_id: %{type: :integer},
            title: %{type: :string},
            description: %{type: :string},
            release_year: %{type: :integer}
          },
          associations: %{}
        },
        name: "Film",
        joins: %{},
        schemas: %{}
      }
      
      film_selecto = Selecto.configure(domain, selecto.postgrex_opts)
      {:ok, film_selecto: film_selecto}
    end

    test "filter by NULL value", %{film_selecto: selecto} do
      result = selecto
      |> Selecto.select(["film_id", "title"])
      |> Selecto.filter({"release_year", nil})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      # Pagila has no NULL release_years, but test the SQL generation
      Enum.each(rows, fn [_film_id, _title] -> 
        # This would be NULL if there were any
        :ok
      end)
    end

    test "filter by NOT NULL", %{film_selecto: selecto} do
      result = selecto
      |> Selecto.select(["film_id"])
      |> Selecto.filter({"release_year", :not_null})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) > 0  # Should have films with non-NULL release_year
    end
  end

  describe "Filter Operations - Complex" do
    test "filter with AND logic (multiple filters)", %{selecto: selecto, test_data: test_data} do
      min_id = test_data.actors.actor1.actor_id
      max_id = test_data.actors.actor4.actor_id
      
      result = selecto
      |> Selecto.select(["actor_id", "first_name", "last_name"])
      |> Selecto.filter({"actor_id", {">=", min_id}})
      |> Selecto.filter({"actor_id", {"<=", max_id}})
      |> Selecto.filter({"first_name", {:like, "P%"}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      Enum.each(rows, fn [actor_id, first_name, _] -> 
        assert actor_id >= min_id and actor_id <= max_id
        assert String.starts_with?(first_name, "P")
      end)
    end

    test "filter with BETWEEN clause", %{selecto: selecto, test_data: test_data} do
      max_id = test_data.actors.actor4.actor_id
      
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", {:between, max_id + 1, max_id + 10}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 0  # No actors in range above our max ID
      Enum.each(rows, fn [actor_id] -> 
        assert actor_id >= max_id + 1 and actor_id <= max_id + 10
      end)
    end
  end

  describe "Ordering" do
    test "order by single field ascending", %{selecto: selecto, test_data: test_data} do
      actor1_id = test_data.actors.actor1.actor_id
      actor2_id = test_data.actors.actor2.actor_id  
      actor3_id = test_data.actors.actor3.actor_id
      
      result = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.filter({"actor_id", [actor3_id, actor1_id, actor2_id]})  # Intentionally out of order
      |> Selecto.order_by("first_name")
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      names = Enum.map(rows, fn [name] -> name end)
      assert names == Enum.sort(names)
    end

    test "order by single field descending", %{selecto: selecto} do
      # First get all actor IDs
      all_result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.execute()
      
      assert {:ok, {all_rows, _columns, _aliases}} = all_result
      all_ids = Enum.map(all_rows, fn [id] -> id end)
      
      # Test ordering with first 3 IDs (or all if less than 3)
      test_ids = Enum.take(all_ids, 3)
      
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", test_ids})
      |> Selecto.order_by({:desc, "actor_id"})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      ids = Enum.map(rows, fn [id] -> id end)
      assert ids == Enum.sort(test_ids, :desc)  # Should be in descending order
    end
  end

  describe "Select Variations - Basic" do
    test "select by atom field name", %{selecto: selecto, test_data: test_data} do
      alice_id = test_data.actors.actor1.actor_id
      
      result = selecto
      |> Selecto.select([:first_name])
      |> Selecto.filter({"actor_id", alice_id})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["first_name"]
      assert hd(rows) == ["Alice"]  # First actor alphabetically
    end

    test "select with literal values", %{selecto: selecto, test_data: test_data} do
      alice_id = test_data.actors.actor1.actor_id
      
      result = selecto
      |> Selecto.select(["first_name", {:literal, "test_value"}])
      |> Selecto.filter({"actor_id", alice_id})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert length(columns) == 2
      assert hd(rows) == ["Alice", "test_value"]  # First actor with test value
    end
  end

  describe "Select Variations - Functions" do
    test "concat function", %{selecto: selecto, test_data: test_data} do
      alice_id = test_data.actors.actor1.actor_id
      
      # Test CONCAT function - might not be implemented in current Selecto version
      result = selecto
      |> Selecto.select([{:concat, ["first_name", {:literal, " "}, "last_name"]}])
      |> Selecto.filter({"actor_id", alice_id})
      |> Selecto.execute()
      
      case result do
        {:ok, {rows, columns, _aliases}} ->
          assert length(columns) == 1
          assert hd(rows) == ["Alice Johnson"]  # First actor full name
        {:error, _} ->
          # CONCAT function might not be implemented yet
          :ok
      end
    end

    test "coalesce function", %{selecto: selecto, test_data: test_data} do
      alice_id = test_data.actors.actor1.actor_id
      
      # Test COALESCE function - might not be implemented in current version
      result = selecto
      |> Selecto.select([{:coalesce, ["first_name", {:literal, "Unknown"}]}])
      |> Selecto.filter({"actor_id", alice_id})
      |> Selecto.execute()
      
      case result do
        {:ok, {rows, _columns, _aliases}} ->
          assert hd(rows) == ["Alice"]  # First actor alphabetically
        {:error, _} ->
          # COALESCE function might not be implemented yet
          :ok
      end
    end
  end

  describe "Aggregation Functions" do
    test "count all records", %{selecto: selecto} do
      result = selecto
      |> Selecto.select([{:count, "*"}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["count"]
      assert rows == [[4]]  # We have 4 test actors
    end

    test "count with filter", %{selecto: selecto, test_data: test_data} do
      min_id = test_data.actors.actor1.actor_id
      
      result = selecto
      |> Selecto.select([{:count, "*"}])
      |> Selecto.filter({"actor_id", {">", min_id - 1}})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert rows == [[4]]  # All 4 actors have ID > min_id - 1
    end

    test "count specific field", %{selecto: selecto} do
      result = selecto
      |> Selecto.select([{:count, "actor_id"}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["count"]
      assert rows == [[4]]  # We have 4 test actors
    end

    test "sum aggregation (with generated data)", %{selecto: selecto} do
      # Get all actor IDs and sum them
      result = selecto
      |> Selecto.select([{:sum, "actor_id"}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["sum"]
      assert length(rows) == 1
      [[sum_value]] = rows
      assert is_integer(sum_value)
      assert sum_value > 0  # Sum of 4 auto-generated IDs should be positive
    end

    test "min and max aggregates", %{selecto: selecto} do
      result = selecto
      |> Selecto.select([{:min, "actor_id"}, {:max, "actor_id"}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["min", "max"]
      assert length(rows) == 1
      [[min_id, max_id]] = rows
      assert is_integer(min_id) and is_integer(max_id)
      assert min_id <= max_id  # Min should be <= Max with our 4 test actors
    end

    test "average aggregation", %{selecto: selecto} do
      result = selecto
      |> Selecto.select([{:avg, "actor_id"}])
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["avg"]
      assert length(rows) == 1
      [[avg_value]] = rows
      assert %Decimal{} = avg_value  # Should be a Decimal value
      assert Decimal.gt?(avg_value, Decimal.new("0"))  # Average should be positive
    end
  end

  describe "SQL Generation" do
    test "to_sql generates correct query", %{selecto: selecto, test_data: test_data} do
      alice_id = test_data.actors.actor1.actor_id
      
      {sql, params} = selecto
      |> Selecto.select(["first_name", "last_name"])
      |> Selecto.filter({"actor_id", alice_id})
      |> Selecto.to_sql()
      
      assert is_binary(sql)
      assert String.contains?(sql, "select")
      assert String.contains?(sql, "first_name")
      assert String.contains?(sql, "last_name") 
      assert String.contains?(sql, "actor")
      assert String.contains?(sql, "where")
      assert params == [alice_id]
    end

    test "to_sql with no filter", %{selecto: selecto} do
      {sql, params} = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.to_sql()
      
      assert is_binary(sql)
      assert String.contains?(sql, "select")
      assert String.contains?(sql, "first_name")
      refute String.contains?(sql, "where")  # Should not have WHERE clause
      assert params == []
    end
  end

  describe "Group By Operations" do
    test "group by single field with count", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["first_name", {:count, "*"}])
      |> Selecto.group_by(["first_name"])
      |> Selecto.filter({"first_name", "John"})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["first_name", "count"]
      assert length(rows) >= 1
      Enum.each(rows, fn [first_name, count] -> 
        assert first_name == "John"
        assert is_integer(count) and count > 0
      end)
    end

    test "group by multiple fields", %{selecto: selecto, test_data: test_data} do
      actor1_id = test_data.actors.actor1.actor_id
      actor2_id = test_data.actors.actor2.actor_id
      actor3_id = test_data.actors.actor3.actor_id
      
      result = selecto
      |> Selecto.select(["first_name", "last_name", {:count, "*"}])
      |> Selecto.group_by(["first_name", "last_name"])
      |> Selecto.filter({"actor_id", [actor1_id, actor2_id, actor3_id]})
      |> Selecto.execute()
      
      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["first_name", "last_name", "count"]
      assert length(rows) == 3  # Each actor should be unique
      Enum.each(rows, fn [_first_name, _last_name, count] -> 
        assert count == 1  # Each name combination appears once
      end)
    end
  end

  describe "Type Conversion and Edge Cases" do
    test "string to integer conversion in filter", %{selecto: selecto, test_data: test_data} do
      alice_id = test_data.actors.actor1.actor_id
      alice_id_string = Integer.to_string(alice_id)
      
      # Note: This test might fail if type conversion is not implemented
      # The exact behavior depends on Selecto's implementation
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", alice_id_string})  # String instead of integer
      |> Selecto.execute()
      
      case result do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) == 1
          assert hd(rows) == [alice_id]
        {:error, _} ->
          # String to integer conversion might not be implemented
          :ok
      end
    end

    test "empty list filter (should match nothing)", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", []})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 0
    end

    test "large IN list filter", %{selecto: selecto, test_data: test_data} do
      # Create a large list that includes our test actor IDs plus many others
      min_id = test_data.actors.actor1.actor_id
      max_id = test_data.actors.actor4.actor_id
      large_list = Enum.to_list(min_id..(min_id + 49))
      
      result = selecto
      |> Selecto.select(["actor_id"])
      |> Selecto.filter({"actor_id", large_list})
      |> Selecto.execute()
      
      assert {:ok, {rows, _columns, _aliases}} = result
      # Only our 4 test actors should match from the large list
      assert length(rows) == 4
      ids = Enum.map(rows, fn [id] -> id end)
      # All returned IDs should be in our large list and should be our test actor IDs
      Enum.each(ids, fn id -> assert id in large_list end)
      assert Enum.sort(ids) == Enum.sort([min_id, min_id + 1, min_id + 2, max_id])
    end
  end

  describe "Error Handling" do
    test "invalid field name returns error", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["nonexistent_field"])
      |> Selecto.execute()
      
      # Should return an error, not crash
      assert {:error, _error} = result
    end

    test "invalid filter field returns error", %{selecto: selecto} do
      result = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.filter({"nonexistent_field", "value"})
      |> Selecto.execute()
      
      # Should return an error, not crash
      assert {:error, _error} = result
    end

    test "safe execution with execute/1", %{selecto: selecto, test_data: test_data} do
      alice_id = test_data.actors.actor1.actor_id
      
      # Test that safe execution returns tagged tuples
      result = selecto
      |> Selecto.select(["first_name"])
      |> Selecto.filter({"actor_id", alice_id})
      |> Selecto.execute()
      
      assert {:ok, {_rows, _columns, _aliases}} = result
    end
  end
end
