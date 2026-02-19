defmodule LiteralValuesTest do
  use SelectoTest.SelectoCase, async: true

  describe "literal values" do
    test "literal strings, integers, and count(*) are not parameterized" do
      domain = %{
        source: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id, :first_name],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            first_name: %{type: :string}
          }
        },
        joins: %{}
      }

      # Use literals that should NOT be parameterized
      selecto =
        Selecto.configure(domain, [], validate: false)
        |> Selecto.select([{:literal, "Hello"}, {:literal, 42}, {:count, "*"}])
        |> Selecto.filter({"actor_id", {">", 0}})

      {sql, _aliases, params} = Selecto.gen_sql(selecto, [])

      # The SQL should contain 'Hello' and 42 as literals, not $1 and $2
      assert sql =~ "'Hello'", "SQL should contain 'Hello' as a literal string"
      assert sql =~ "42", "SQL should contain 42 as a literal number"
      assert sql =~ ~r/count\(\*\)/i, "SQL should contain COUNT(*)"

      # There should only be one parameter (for 0 in the filter), not three
      assert length(params) == 1, "Should have exactly 1 parameter for the filter value"
      assert params == [0], "Parameter should be 0 from the filter"
    end

    test "literal floats are not parameterized" do
      domain = %{
        source: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id],
          redact_fields: [],
          columns: %{actor_id: %{type: :integer}}
        },
        joins: %{}
      }

      selecto =
        Selecto.configure(domain, [], validate: false)
        |> Selecto.select([{:literal, 3.14}])

      {sql, _aliases, params} = Selecto.gen_sql(selecto, [])

      assert sql =~ "3.14", "SQL should contain 3.14 as a literal float"
      assert params == [], "Should have no parameters"
    end

    test "literal booleans are not parameterized" do
      domain = %{
        source: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id],
          redact_fields: [],
          columns: %{actor_id: %{type: :integer}}
        },
        joins: %{}
      }

      selecto =
        Selecto.configure(domain, [], validate: false)
        |> Selecto.select([{:literal, true}, {:literal, false}])

      {sql, _aliases, params} = Selecto.gen_sql(selecto, [])

      assert sql =~ ~r/TRUE/i, "SQL should contain TRUE"
      assert sql =~ ~r/FALSE/i, "SQL should contain FALSE"
      assert params == [], "Should have no parameters"
    end

    test "literal null is not parameterized" do
      domain = %{
        source: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id],
          redact_fields: [],
          columns: %{actor_id: %{type: :integer}}
        },
        joins: %{}
      }

      selecto =
        Selecto.configure(domain, [], validate: false)
        |> Selecto.select([{:literal, nil}])

      {sql, _aliases, params} = Selecto.gen_sql(selecto, [])

      assert sql =~ ~r/NULL/i, "SQL should contain NULL"
      assert params == [], "Should have no parameters"
    end

    test "literal strings with single quotes are escaped" do
      domain = %{
        source: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id],
          redact_fields: [],
          columns: %{actor_id: %{type: :integer}}
        },
        joins: %{}
      }

      selecto =
        Selecto.configure(domain, [], validate: false)
        |> Selecto.select([{:literal, "O'Reilly"}])

      {sql, _aliases, params} = Selecto.gen_sql(selecto, [])

      assert sql =~ "'O''Reilly'", "SQL should escape single quotes by doubling them"
      assert params == [], "Should have no parameters"
    end
  end

  describe "COUNT(*) with FILTER" do
    test "count(*) with filter does not parameterize the asterisk" do
      domain = %{
        source: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id, :first_name, :last_name],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            first_name: %{type: :string},
            last_name: %{type: :string}
          }
        },
        joins: %{}
      }

      # Use count(*) with a filter
      selecto =
        Selecto.configure(domain, [], validate: false)
        |> Selecto.select([{:count, "*", {"first_name", {"!=", "DAN"}}}])

      {sql, _aliases, params} = Selecto.gen_sql(selecto, [])

      # The SQL should contain COUNT(*) not COUNT($1)
      assert sql =~ ~r/count\(\*\)/i, "SQL should contain COUNT(*), not COUNT($1)"

      # There should only be one parameter (for "DAN"), not two
      assert length(params) == 1, "Should have exactly 1 parameter for 'DAN'"
      assert params == ["DAN"], "Parameter should be 'DAN'"

      # Ensure the SQL has the FILTER clause
      assert sql =~ ~r/filter/i, "SQL should contain FILTER clause"
    end

    test "count(*) without filter works correctly" do
      domain = %{
        source: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id, :first_name],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            first_name: %{type: :string}
          }
        },
        joins: %{}
      }

      selecto =
        Selecto.configure(domain, [], validate: false)
        |> Selecto.select([{:count, "*"}])

      {sql, _aliases, params} = Selecto.gen_sql(selecto, [])

      # Simple COUNT(*)
      assert sql =~ ~r/count\(\*\)/i
      assert params == []
    end
  end
end
