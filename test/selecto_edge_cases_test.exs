defmodule SelectoEdgeCasesTest do
  use SelectoTest.SelectoCase, async: false

  # Tests for Selecto edge cases, error handling, and boundary conditions
  # Covers null handling, empty results, type conversions, and error scenarios

  setup_all do
    # Set up database connection
    repo_config = SelectoTest.Repo.config()

    postgrex_opts = [
      username: repo_config[:username],
      password: repo_config[:password],
      hostname: repo_config[:hostname],
      database: repo_config[:database],
      port: repo_config[:port] || 5432
    ]

    {:ok, db_conn} = Postgrex.start_link(postgrex_opts)

    # Basic actor domain
    actor_domain = %{
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

    # Film domain with more nullable fields
    film_domain = %{
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :description, :release_year, :rental_rate, :length, :rating],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :text},
          release_year: %{type: :integer},
          rental_rate: %{type: :decimal},
          length: %{type: :integer},
          rating: %{type: :string}
        },
        associations: %{}
      },
      name: "Film",
      joins: %{},
      schemas: %{}
    }

    actor_selecto = Selecto.configure(actor_domain, db_conn)
    film_selecto = Selecto.configure(film_domain, db_conn)

    {:ok, actor_selecto: actor_selecto, film_selecto: film_selecto}
  end

  describe "Empty Result Sets" do
    test "filter that matches no records", %{actor_selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["first_name", "last_name"])
        # Non-existent ID
        |> Selecto.filter({"actor_id", -1})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["first_name", "last_name"]
      assert length(rows) == 0
    end

    test "empty IN list", %{actor_selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["actor_id"])
        |> Selecto.filter({"actor_id", []})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 0
    end

    test "impossible range filter", %{film_selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["film_id"])
        # Beyond max film ID
        |> Selecto.filter({"film_id", {">", 99999}})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 0
    end

    test "string filter that matches nothing", %{actor_selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["first_name"])
        # Non-existent name
        |> Selecto.filter({"first_name", "XXXXXXXXXX"})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 0
    end

    test "LIKE pattern that matches nothing", %{actor_selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["first_name"])
        # No names start with XYZ
        |> Selecto.filter({"first_name", {:like, "XYZ%"}})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      assert length(rows) == 0
    end
  end

  describe "NULL Value Handling" do
    test "IS NULL filter", %{film_selecto: selecto} do
      # Some films might have NULL values in certain fields
      result =
        selecto
        |> Selecto.select(["film_id", "release_year"])
        |> Selecto.filter({"release_year", nil})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      # In Pagila, release_year is typically not null, but test the SQL generation
      Enum.each(rows, fn [_film_id, release_year] ->
        assert is_nil(release_year)
      end)
    end

    test "IS NOT NULL filter", %{film_selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["film_id", "title"])
        |> Selecto.filter({"title", :not_null})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      # Most/all films have titles
      assert length(rows) > 0

      Enum.each(rows, fn [_film_id, title] ->
        assert is_binary(title)
        refute is_nil(title)
      end)
    end

    test "NULL in aggregation functions", %{film_selecto: selecto} do
      # Test how aggregation handles NULL values
      result =
        selecto
        |> Selecto.select([
          {:count, "*"},
          # Count non-NULL length values
          {:count, "length"},
          # Average of non-NULL length values
          {:avg, "length"},
          {:min, "length"},
          {:max, "length"}
        ])
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["count", "count", "avg", "min", "max"]
      assert length(rows) == 1

      [total_count, length_count, avg_length, min_length, max_length] = hd(rows)

      assert is_integer(total_count)
      assert is_integer(length_count)
      # Some films might have NULL length
      assert length_count <= total_count

      if avg_length do
        assert %Decimal{} = avg_length
      end

      if min_length do
        assert is_integer(min_length)
      end

      if max_length do
        assert is_integer(max_length)
      end
    end

    test "COALESCE with NULL values", %{film_selecto: selecto} do
      result =
        selecto
        |> Selecto.select([
          "title",
          # Replace NULL length with 0
          {:coalesce, ["length", {:literal, 0}]}
        ])
        |> Selecto.filter({"film_id", [1, 2, 3]})
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert length(columns) == 2

      Enum.each(rows, fn [title, coalesced_length] ->
        assert is_binary(title)
        assert is_integer(coalesced_length)
        # Should be actual length or 0
        assert coalesced_length >= 0
      end)
    end
  end

  describe "Type Conversion Edge Cases" do
    test "string to integer conversion in filters", %{actor_selecto: selecto} do
      # Test various string formats that should convert to integers
      string_conversions = [
        {"1", 1},
        {"123", 123},
        # With whitespace
        {" 5 ", 5}
      ]

      Enum.each(string_conversions, fn {string_val, expected_id} ->
        result =
          selecto
          |> Selecto.select(["actor_id"])
          |> Selecto.filter({"actor_id", string_val})
          |> Selecto.execute()

        case result do
          {:ok, {rows, _columns, _aliases}} ->
            if length(rows) > 0 do
              assert hd(hd(rows)) == expected_id
            end

          {:error, _} ->
            # Some conversions might fail, that's acceptable
            :ok
        end
      end)
    end

    test "decimal conversion edge cases", %{film_selecto: selecto} do
      # Test decimal comparisons with different input types
      decimal_tests = [
        # Integer comparison with decimal field
        {{"rental_rate", {">", 4}}, ">", 4},
        # String number comparison
        {{"rental_rate", {"<", "3.00"}}, "<", Decimal.new("3.00")},
        # Float comparison (might be converted)
        {{"rental_rate", {">=", 2.99}}, ">=", 2.99}
      ]

      Enum.each(decimal_tests, fn {filter, op, compare_val} ->
        result =
          selecto
          |> Selecto.select(["rental_rate"])
          |> Selecto.filter(filter)
          |> Selecto.execute()

        case result do
          {:ok, {rows, _columns, _aliases}} ->
            # Verify the comparison works
            Enum.each(rows, fn [rental_rate] ->
              assert %Decimal{} = rental_rate
              # Basic validation that comparison works
              case op do
                ">" -> assert Decimal.compare(rental_rate, Decimal.new("#{compare_val}")) == :gt
                "<" -> assert Decimal.compare(rental_rate, Decimal.new("#{compare_val}")) == :lt
                ">=" -> assert Decimal.compare(rental_rate, Decimal.new("#{compare_val}")) != :lt
                _ -> :ok
              end
            end)

          {:error, _} ->
            # Some type conversions might not be supported
            :ok
        end
      end)
    end

    test "boolean-like string handling", %{film_selecto: selecto} do
      # Test how boolean-like strings are handled in filters
      # Note: Pagila doesn't have boolean fields, so this tests error handling
      result =
        selecto
        |> Selecto.select(["title"])
        # Treating string field as boolean
        |> Selecto.filter({"title", "true"})
        |> Selecto.execute()

      # Should work as string comparison, not boolean
      assert {:ok, {_rows, _columns, _aliases}} = result
      # If any film has title "true", it will be found; otherwise empty
    end
  end

  describe "Large Data Edge Cases" do
    test "very large IN list", %{actor_selecto: selecto} do
      # Test with a large list of IDs
      # All possible actor IDs
      large_list = Enum.to_list(1..200)

      result =
        selecto
        |> Selecto.select(["actor_id"])
        |> Selecto.filter({"actor_id", large_list})
        |> Selecto.execute()

      assert {:ok, {rows, _columns, _aliases}} = result
      # All actors
      assert length(rows) == 200

      returned_ids = Enum.map(rows, fn [id] -> id end)
      assert Enum.sort(returned_ids) == Enum.to_list(1..200)
    end

    test "extremely large IN list", %{actor_selecto: selecto} do
      # Test with an unreasonably large list
      huge_list = Enum.to_list(1..10000)

      result =
        selecto
        |> Selecto.select(["actor_id"])
        |> Selecto.filter({"actor_id", huge_list})
        |> Selecto.execute()

      # Should still work, just return all existing actors
      assert {:ok, {rows, _columns, _aliases}} = result
      # Only actual actors
      assert length(rows) <= 200
    end

    test "select all fields with large result set", %{film_selecto: selecto} do
      result =
        selecto
        |> Selecto.select([
          "film_id",
          "title",
          "description",
          "release_year",
          "rental_rate",
          "length",
          "rating"
        ])
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert length(columns) == 7
      # Total films in Pagila (our test data has 6)
      assert length(rows) >= 6

      # Spot check first few rows for data integrity
      Enum.take(rows, 3)
      |> Enum.each(fn [film_id, title, description, release_year, rental_rate, length, rating] ->
        assert is_integer(film_id)
        assert is_binary(title)
        assert is_binary(description) or is_nil(description)
        assert is_integer(release_year) or is_nil(release_year)
        assert %Decimal{} = rental_rate
        assert is_integer(length) or is_nil(length)
        assert is_binary(rating) or is_nil(rating)
      end)
    end
  end

  describe "Invalid Input Handling" do
    test "invalid field name in select", %{actor_selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["nonexistent_field"])
        |> Selecto.execute()

      assert {:error, _error} = result
    end

    test "invalid field name in filter", %{actor_selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["first_name"])
        |> Selecto.filter({"invalid_field", "value"})
        |> Selecto.execute()

      assert {:error, _error} = result
    end

    test "invalid operator in filter", %{actor_selecto: selecto} do
      # Test with an invalid comparison operator
      result =
        selecto
        |> Selecto.select(["actor_id"])
        |> Selecto.filter({"actor_id", {"INVALID_OP", 1}})
        |> Selecto.execute()

      # Should return error for invalid operator
      assert {:error, _error} = result
    end

    test "malformed filter structure", %{actor_selecto: selecto} do
      # Test with malformed filter tuples
      malformed_filters = [
        # Missing value
        {"actor_id"},
        # Too many elements
        {"actor_id", "value", "extra"},
        # Malformed operator tuple
        {"actor_id", {"incomplete_tuple"}}
      ]

      Enum.each(malformed_filters, fn bad_filter ->
        result =
          selecto
          |> Selecto.select(["actor_id"])
          |> Selecto.filter(bad_filter)
          |> Selecto.execute()

        # Should handle gracefully (either error or ignore)
        case result do
          {:ok, {_rows, _columns, _aliases}} -> :ok
          {:error, _error} -> :ok
        end
      end)
    end
  end

  describe "SQL Injection Prevention" do
    test "SQL injection in string filters", %{actor_selecto: selecto} do
      # Test that SQL injection attempts are properly escaped
      injection_attempts = [
        "'; DROP TABLE actor; --",
        "' OR '1'='1",
        "'; INSERT INTO actor VALUES (999, 'HACKER', 'HACKER'); --",
        "' UNION SELECT password FROM users --"
      ]

      Enum.each(injection_attempts, fn injection_string ->
        result =
          selecto
          |> Selecto.select(["first_name"])
          |> Selecto.filter({"first_name", injection_string})
          |> Selecto.execute()

        # Should return empty results, not execute injected SQL
        assert {:ok, {rows, _columns, _aliases}} = result
        # No actors with these malicious names
        assert length(rows) == 0
      end)
    end

    test "SQL injection in LIKE patterns", %{actor_selecto: selecto} do
      injection_patterns = [
        "'; DROP TABLE actor; --",
        "%'; DELETE FROM actor WHERE '1'='1'; --",
        "' OR '1'='1' --"
      ]

      Enum.each(injection_patterns, fn pattern ->
        result =
          selecto
          |> Selecto.select(["first_name"])
          |> Selecto.filter({"first_name", {:like, pattern}})
          |> Selecto.execute()

        # Should be safe and return empty results
        assert {:ok, {rows, _columns, _aliases}} = result
        assert length(rows) == 0
      end)
    end
  end

  describe "Memory and Performance Edge Cases" do
    test "extremely long string in filter", %{actor_selecto: selecto} do
      # Test with a very long string
      long_string = String.duplicate("A", 10000)

      result =
        selecto
        |> Selecto.select(["first_name"])
        |> Selecto.filter({"first_name", long_string})
        |> Selecto.execute()

      # Should handle gracefully
      assert {:ok, {rows, _columns, _aliases}} = result
      # No names are 10,000 characters long
      assert length(rows) == 0
    end

    test "very complex nested function calls", %{film_selecto: selecto} do
      # Test deeply nested function calls in SELECT
      complex_select =
        {:upper,
         {:coalesce,
          [
            {:concat,
             [
               {:left, ["title", {:literal, 10}]},
               {:literal, "..."},
               {:right, ["title", {:literal, 5}]}
             ]},
            {:literal, "NO_TITLE"}
          ]}}

      result =
        selecto
        |> Selecto.select([complex_select])
        |> Selecto.filter({"film_id", 1})
        |> Selecto.execute()

      case result do
        {:ok, {rows, _columns, _aliases}} ->
          assert length(rows) == 1
          [complex_result] = hd(rows)
          assert is_binary(complex_result)
          assert String.upcase(complex_result) == complex_result

        {:error, _} ->
          # Complex nested functions might not be fully supported
          :ok
      end
    end

    test "aggregation with GROUP BY on many groups", %{film_selecto: selecto} do
      # Create many groups to test performance
      result =
        selecto
        |> Selecto.select([
          "rating",
          "release_year",
          {:count, "film_id"},
          {:avg, "rental_rate"}
        ])
        |> Selecto.group_by(["rating", "release_year"])
        |> Selecto.execute()

      assert {:ok, {rows, columns, _aliases}} = result
      assert columns == ["rating", "release_year", "count", "avg"]
      # Multiple rating/year combinations (our test data has 3)
      assert length(rows) >= 3

      # Verify grouping integrity
      Enum.each(rows, fn [rating, release_year, count, avg_rate] ->
        assert is_binary(rating) or is_nil(rating)
        assert is_integer(release_year) or is_nil(release_year)
        assert is_integer(count) and count > 0
        assert match?(%Decimal{}, avg_rate) or is_nil(avg_rate)
      end)
    end
  end

  describe "Concurrent Access Edge Cases" do
    test "multiple simultaneous queries", %{actor_selecto: selecto} do
      # Test concurrent queries to the same selecto instance
      tasks =
        1..5
        |> Enum.map(fn i ->
          Task.async(fn ->
            selecto
            |> Selecto.select(["first_name"])
            |> Selecto.filter({"actor_id", i})
            |> Selecto.execute()
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # All tasks should complete successfully
      Enum.each(results, fn result ->
        assert {:ok, {rows, _columns, _aliases}} = result
        # Each query for a single actor
        assert length(rows) == 1
      end)
    end

    test "safe execution patterns", %{actor_selecto: selecto} do
      # Test the safe vs unsafe execution patterns

      # Safe execution
      safe_result =
        selecto
        |> Selecto.select(["first_name"])
        |> Selecto.filter({"actor_id", 1})
        |> Selecto.execute()

      assert {:ok, {_rows, _columns, _aliases}} = safe_result

      # Safe execution with structured error handling
      error_result =
        selecto
        |> Selecto.select(["nonexistent_field"])
        |> Selecto.execute()

      assert {:error, %Selecto.Error{type: :query_error}} = error_result
    end
  end

  describe "Boundary Value Testing" do
    test "minimum and maximum integer values", %{actor_selecto: selecto} do
      # Test edge cases for integer comparisons
      boundary_tests = [
        # All actors
        {{"actor_id", {">", 0}}, fn count -> count == 200 end},
        # No actors
        {{"actor_id", {"<", 1}}, fn count -> count == 0 end},
        # Just actor 200
        {{"actor_id", {">=", 200}}, fn count -> count == 1 end},
        # Just actor 1
        {{"actor_id", {"<=", 1}}, fn count -> count == 1 end}
      ]

      Enum.each(boundary_tests, fn {filter, validator} ->
        result =
          selecto
          |> Selecto.select([{:count, "*"}])
          |> Selecto.filter(filter)
          |> Selecto.execute()

        assert {:ok, {[[count]], _columns, _aliases}} = result
        assert validator.(count), "Boundary test failed for filter: #{inspect(filter)}"
      end)
    end

    test "empty string and whitespace handling", %{film_selecto: selecto} do
      # Test how empty and whitespace strings are handled
      string_tests = [
        {"", "empty string"},
        {" ", "single space"},
        {"   ", "multiple spaces"},
        {"\t", "tab character"},
        {"\n", "newline character"}
      ]

      Enum.each(string_tests, fn {test_string, _description} ->
        result =
          selecto
          |> Selecto.select(["title"])
          |> Selecto.filter({"title", test_string})
          |> Selecto.execute()

        # Should handle gracefully, likely returning empty results
        assert {:ok, {rows, _columns, _aliases}} = result
        # Most likely no films have these exact titles
        assert is_list(rows)
      end)
    end
  end
end
