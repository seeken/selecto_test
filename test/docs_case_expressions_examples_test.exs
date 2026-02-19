defmodule DocsCaseExpressionsExamplesTest do
  use ExUnit.Case, async: true
  import SelectoTest.TestHelpers

  @moduledoc """
  Tests demonstrating CASE expression functionality using the actual Selecto API.
  CASE expressions use the format: {:case, when_clauses, else_clause}
  where when_clauses is a list of {{field, value}, result} tuples.
  """

  describe "Simple CASE Expressions from Docs" do
    test "basic value mapping for film ratings" do
      selecto = configure_test_selecto("film")

      # Using the actual {:case, when_clauses, else_clause} format
      result =
        selecto
        |> Selecto.select([
          "title",
          {:case,
           [
             {{"rating", "G"}, {:literal, "General Audiences"}},
             {{"rating", "PG"}, {:literal, "Parental Guidance Suggested"}},
             {{"rating", "PG-13"}, {:literal, "Parents Strongly Cautioned"}},
             {{"rating", "R"}, {:literal, "Restricted"}},
             {{"rating", "NC-17"}, {:literal, "Adults Only"}}
           ], {:literal, "Not Rated"}}
        ])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/case/i
      assert sql =~ ~r/when.*rating.*=/i
      assert sql =~ ~r/then/i
      assert sql =~ ~r/else/i
      # Check params contain expected values
      assert sql =~ "'General Audiences'"
      assert sql =~ "'Parental Guidance Suggested'"
      assert sql =~ "'Not Rated'"
    end

    test "numeric comparison in CASE" do
      selecto = configure_test_selecto("film")

      # Using comparison operators in CASE
      result =
        selecto
        |> Selecto.select([
          "title",
          "length",
          {:case,
           [
             {{"length", {">", 120}}, {:literal, "Long"}},
             {{"length", {">=", 90}}, {:literal, "Medium"}}
           ], {:literal, "Short"}}
        ])

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/case/i
      assert sql =~ ~r/length.*>/i
      assert sql =~ ~r/then/i
      assert sql =~ ~r/else/i
      # Check SQL contains literal values (not parameterized)
      assert sql =~ "'Long'"
      assert sql =~ "'Medium'"
      assert sql =~ "'Short'"
      # Check params contain comparison values (parameterized)
      assert 120 in params
      assert 90 in params
    end

    test "simple CASE without ELSE clause" do
      selecto = configure_test_selecto("film")

      # CASE without ELSE clause - just omit the third argument
      result =
        selecto
        |> Selecto.select([
          "title",
          {:case,
           [
             {{"rating", "G"}, {:literal, "Safe for Kids"}},
             {{"rating", "PG"}, {:literal, "Ask Parents"}}
           ]}
        ])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/case/i
      assert sql =~ ~r/when.*rating.*=/i
      assert sql =~ ~r/then/i
      refute sql =~ ~r/else/i
      # Check params
      assert sql =~ "'Safe for Kids'"
      assert sql =~ "'Ask Parents'"
    end

    test "CASE with rental rate classification" do
      selecto = configure_test_selecto("film")

      # Decimal value comparisons
      result =
        selecto
        |> Selecto.select([
          "film_id",
          "rental_rate",
          {:case,
           [
             {{"rental_rate", {">=", 4.99}}, {:literal, "Premium"}},
             {{"rental_rate", {">=", 2.99}}, {:literal, "Standard"}},
             {{"rental_rate", {">=", 0.99}}, {:literal, "Budget"}}
           ], {:literal, "Free"}}
        ])

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/case/i
      assert sql =~ ~r/rental_rate.*>=/i
      assert sql =~ ~r/then/i
      assert sql =~ ~r/else/i
      # Check params
      assert sql =~ "'Premium'"
      assert sql =~ "'Standard'"
      assert sql =~ "'Budget'"
      assert sql =~ "'Free'"
      assert Enum.any?(params, fn p -> p == 4.99 or p == 2.99 or p == 0.99 end)
    end
  end

  describe "Complex CASE Expressions" do
    test "film classification by multiple criteria" do
      selecto = configure_test_selecto("film")

      # Multiple CASE expressions in one query
      result =
        selecto
        |> Selecto.select([
          "title",
          {:case,
           [
             {{"rating", "G"}, {:literal, "Family"}},
             {{"rating", "PG"}, {:literal, "Family"}},
             {{"rating", "PG-13"}, {:literal, "Teen"}},
             {{"rating", "R"}, {:literal, "Adult"}},
             {{"rating", "NC-17"}, {:literal, "Adult"}}
           ], {:literal, "Unrated"}},
          {:case,
           [
             {{"length", {">", 180}}, {:literal, "Epic"}},
             {{"length", {">", 120}}, {:literal, "Long"}},
             {{"length", {">=", 90}}, {:literal, "Standard"}},
             {{"length", {">=", 60}}, {:literal, "Short"}}
           ], {:literal, "Very Short"}}
        ])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      # Should have two case statements
      case_matches = Regex.scan(~r/\bcase\b/i, sql)
      assert length(case_matches) == 2
      # Check params for values
      assert sql =~ "'Family'"
      assert sql =~ "'Teen'"
      assert sql =~ "'Adult'"
      assert sql =~ "'Epic'"
      assert sql =~ "'Long'"
      assert sql =~ "'Standard'"
    end

    test "CASE in aggregation context" do
      selecto = configure_test_selecto("film")

      # Using CASE with aggregation
      result =
        selecto
        |> Selecto.select([
          "rating",
          {:count, "film_id"},
          {:case,
           [
             {{"rating", ["G", "PG"]}, {:literal, "Family Friendly"}},
             {{"rating", ["PG-13"]}, {:literal, "Teen Appropriate"}},
             {{"rating", ["R", "NC-17"]}, {:literal, "Adult Only"}}
           ], {:literal, "Unknown"}}
        ])
        |> Selecto.group_by(["rating"])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/case/i
      assert sql =~ ~r/count/i
      assert sql =~ ~r/group by/i
      # Check params
      assert sql =~ "'Family Friendly'"
      assert sql =~ "'Teen Appropriate'"
      assert sql =~ "'Adult Only'"
    end
  end

  describe "Edge Cases and Special Scenarios" do
    test "CASE with NULL comparisons" do
      selecto = configure_test_selecto("film")

      # Testing NULL handling
      result =
        selecto
        |> Selecto.select([
          "title",
          {:case,
           [
             {{"special_features", nil}, {:literal, "No Special Features"}},
             {{"special_features", {:not, nil}}, {:literal, "Has Special Features"}}
           ]}
        ])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/case/i
      assert sql =~ ~r/special_features.*is/i
      assert sql =~ ~r/then/i
      # Check params
      assert sql =~ "'No Special Features'"
      assert sql =~ "'Has Special Features'"
    end

    test "nested value expressions in CASE" do
      selecto = configure_test_selecto("film")

      # Using other aggregate functions as results
      result =
        selecto
        |> Selecto.select([
          "rating",
          {:case,
           [
             {{"rating", ["G", "PG"]}, {:count, "film_id"}},
             {{"rating", ["R", "NC-17"]}, {:sum, "rental_rate"}}
           ], {:literal, 0}}
        ])
        |> Selecto.group_by(["rating"])

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/case/i
      assert sql =~ ~r/count.*film_id/i or sql =~ ~r/count\(/i
      assert sql =~ ~r/sum.*rental_rate/i or sql =~ ~r/sum\(/i
      assert sql =~ ~r/group by.*rating/i
      # Check SQL contains literal 0 (not parameterized)
      assert sql =~ ~r/else\s+0/i
      # Check params contain the IN clause arrays
      assert ["G", "PG"] in params
      assert ["R", "NC-17"] in params
    end
  end

  describe "CASE in WHERE Clause" do
    test "conditional filtering with CASE" do
      selecto = configure_test_selecto("film")

      # Filter using a CASE expression
      # WHERE CASE WHEN rating = 'R' THEN length > 120 ELSE length > 90 END
      result =
        selecto
        |> Selecto.select(["title", "rating", "length"])
        |> Selecto.filter(
          {:case,
           [
             {{"rating", "R"}, {"length", {">", 120}}},
             {{"rating", "PG-13"}, {"length", {">", 100}}}
           ], {"length", {">", 90}}}
        )

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/where.*case/i
      assert sql =~ ~r/when.*rating.*=.*then.*length.*>/i
      assert sql =~ ~r/else.*length.*>/i
      assert sql =~ ~r/end/i
      assert 120 in params
      assert 90 in params
    end

    test "CASE returning boolean in WHERE" do
      selecto = configure_test_selecto("film")

      # WHERE CASE WHEN rating IN ('G', 'PG') THEN TRUE ELSE FALSE END
      result =
        selecto
        |> Selecto.select(["title", "rating"])
        |> Selecto.filter(
          {:case,
           [
             {{"rating", ["G", "PG"]}, true}
           ], false}
        )

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/where.*case/i
      assert sql =~ ~r/when.*rating.*=.*any/i
      assert sql =~ ~r/then.*true/i
      assert sql =~ ~r/else.*false/i
    end
  end

  describe "CASE in ORDER BY Clause" do
    test "conditional ordering with CASE" do
      selecto = configure_test_selecto("film")

      # ORDER BY CASE WHEN rating = 'G' THEN 1 WHEN rating = 'PG' THEN 2 ELSE 3 END
      result =
        selecto
        |> Selecto.select(["title", "rating"])
        |> Selecto.order_by([
          {:case,
           [
             {{"rating", "G"}, 1},
             {{"rating", "PG"}, 2},
             {{"rating", "PG-13"}, 3}
           ], 4}
        ])

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/order by.*case/i
      assert sql =~ ~r/when.*rating.*=.*then/i
      # ELSE uses a parameter
      assert sql =~ ~r/else.*\$\d+/i
      assert sql =~ ~r/end/i
      # Check that 4 is in the params
      assert 4 in params
    end

    test "multiple ORDER BY with CASE" do
      selecto = configure_test_selecto("film")

      # ORDER BY CASE..., title ASC
      result =
        selecto
        |> Selecto.select(["title", "rating", "length"])
        |> Selecto.order_by([
          {:case,
           [
             {{"rating", "G"}, 1},
             {{"rating", "PG"}, 2}
           ], 99},
          {"title", :asc}
        ])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/order by.*case.*when.*then.*end.*,.*title/i
    end
  end
end
