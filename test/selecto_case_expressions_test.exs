defmodule SelectoCaseExpressionsTest do
  use SelectoTest.SelectoCase, async: false

  # Tests for Selecto CASE expression functionality
  # Covers simple CASE, searched CASE, complex conditions, and edge cases

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

    # Film domain for testing CASE expressions
    domain = %{
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [
          :film_id,
          :title,
          :description,
          :release_year,
          :language_id,
          :rental_duration,
          :rental_rate,
          :length,
          :replacement_cost,
          :rating,
          :last_update
        ],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :text},
          release_year: %{type: :integer},
          language_id: %{type: :integer},
          rental_duration: %{type: :integer},
          rental_rate: %{type: :decimal},
          length: %{type: :integer},
          replacement_cost: %{type: :decimal},
          rating: %{type: :string},
          last_update: %{type: :utc_datetime}
        },
        associations: %{}
      },
      name: "Film",
      joins: %{},
      schemas: %{}
    }

    selecto = Selecto.configure(domain, db_conn)

    {:ok, selecto: selecto, db_conn: db_conn}
  end

  setup do
    {:ok, []}
  end

  describe "simple CASE expressions" do
    test "basic simple CASE with rating transformation", %{selecto: selecto} do
      result =
        selecto
        # Select base fields first
        |> Selecto.select(["title"])
        |> Selecto.case_select(
          "rating",
          [
            {"G", "General Audience"},
            {"PG", "Parental Guidance"},
            {"PG-13", "Parents Strongly Cautioned"},
            {"R", "Restricted"}
          ], else: "Not Rated", as: "rating_description")
        # Limit results
        |> Selecto.filter([{"film_id", {:<, 20}}])
        |> Selecto.execute()

      assert {:ok, {results, _columns, _aliases}} = result
      assert length(results) > 0

      # Check that we have the expected columns
      [first_result | _] = results
      # title and rating_description
      assert length(first_result) == 2
    end

    test "simple CASE without ELSE clause", %{selecto: selecto} do
      result =
        selecto
        # Select base fields first
        |> Selecto.select(["title", "rating"])
        |> Selecto.case_select(
          "rating",
          [
            {"G", "Family Friendly"},
            {"PG", "Family Safe"}
          ], as: "family_rating")
        |> Selecto.filter([{"rating", {:in, ["G", "PG", "R"]}}])
        # Limit results
        |> Selecto.filter([{"film_id", {:<, 20}}])
        |> Selecto.execute()

      assert {:ok, {results, _columns, _aliases}} = result
      assert length(results) > 0

      # Check that we have the expected columns
      [first_result | _] = results
      # title, family_rating, rating
      assert length(first_result) == 3
    end
  end

  describe "searched CASE expressions" do
    test "basic searched CASE with length categories", %{selecto: selecto} do
      result =
        selecto
        # Select base fields first
        |> Selecto.select(["title", "length"])
        |> Selecto.case_when_select(
          [
            {[{"length", {:>, 120}}], "Long Film"},
            {[{"length", {:between, 90, 120}}], "Standard Film"},
            {[{"length", {:>, 0}}], "Short Film"}
          ], else: "Unknown", as: "length_category")
        |> Selecto.filter([{"length", {:not, nil}}])
        # Limit results
        |> Selecto.filter([{"film_id", {:<, 20}}])
        |> Selecto.execute()

      assert {:ok, {results, _columns, _aliases}} = result
      assert length(results) > 0

      # Check that we have the expected columns
      [first_result | _] = results
      # title, length_category, length
      assert length(first_result) == 3
    end

    test "searched CASE with multiple conditions", %{selecto: selecto} do
      result =
        selecto
        # Select base fields first
        |> Selecto.select(["title", "rating", "length"])
        |> Selecto.case_when_select(
          [
            {[{"rating", "R"}, {"length", {:>, 120}}], "Long Adult Film"},
            {[{"rating", {:in, ["PG", "PG-13"]}}], "Teen Film"}
          ], else: "Regular Film", as: "film_category")
        # Limit results
        |> Selecto.filter([{"film_id", {:<, 30}}])
        |> Selecto.execute()

      assert {:ok, {results, _columns, _aliases}} = result
      assert length(results) > 0

      # Check that we have the expected columns
      [first_result | _] = results
      # title, film_category, rating, length
      assert length(first_result) == 4
    end
  end

  describe "CASE expression SQL generation" do
    test "simple CASE generates correct SQL", %{selecto: selecto} do
      {sql, _aliases, params} =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.case_select(
          "rating",
          [
            {"G", "General"},
            {"PG", "Parental"}
          ], else: "Other", as: "rating_desc")
        |> Selecto.gen_sql([])

      assert String.contains?(sql, "CASE rating")
      assert String.contains?(sql, "WHEN")
      assert String.contains?(sql, "THEN")
      assert String.contains?(sql, "ELSE")
      assert String.contains?(sql, "END AS rating_desc")

      # Check that parameters are properly bound
      assert "G" in params
      assert "General" in params
      assert "PG" in params
      assert "Parental" in params
      assert "Other" in params
    end

    test "searched CASE generates correct SQL", %{selecto: selecto} do
      {sql, _aliases, params} =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.case_when_select(
          [
            {[{"length", {:>, 120}}], "Long"},
            {[{"length", {:<, 90}}], "Short"}
          ], else: "Medium", as: "length_desc")
        |> Selecto.gen_sql([])

      assert String.contains?(sql, "CASE")
      assert String.contains?(sql, "WHEN")
      assert String.contains?(sql, "THEN")
      assert String.contains?(sql, "ELSE")
      assert String.contains?(sql, "END AS length_desc")

      # Check that parameters are properly bound
      assert 120 in params
      assert "Long" in params
      assert 90 in params
      assert "Short" in params
      assert "Medium" in params
    end
  end

  describe "CASE expression validation" do
    test "simple CASE requires column", %{selecto: _selecto} do
      assert_raise Selecto.Advanced.CaseExpression.ValidationError,
                   ~r/Simple CASE expression must have a column/,
                   fn ->
                     Selecto.Advanced.CaseExpression.create_simple_case(nil, [{"G", "General"}])
                   end
    end

    test "simple CASE validates WHEN clauses format", %{selecto: _selecto} do
      assert_raise Selecto.Advanced.CaseExpression.ValidationError,
                   ~r/Simple CASE WHEN clauses must be/,
                   fn ->
                     Selecto.Advanced.CaseExpression.create_simple_case("rating", [{"G"}])
                   end
    end

    test "searched CASE validates WHEN clauses format", %{selecto: _selecto} do
      assert_raise Selecto.Advanced.CaseExpression.ValidationError,
                   ~r/Searched CASE WHEN clauses must be/,
                   fn ->
                     Selecto.Advanced.CaseExpression.create_searched_case([{"invalid"}])
                   end
    end

    test "CASE specification must be validated before SQL generation", %{selecto: _selecto} do
      # Create an unvalidated spec manually
      unvalidated_spec = %Selecto.Advanced.CaseExpression.Spec{
        id: "test_case",
        type: :simple,
        column: "test",
        when_clauses: [{"A", "B"}],
        validated: false
      }

      assert_raise ArgumentError, ~r/must be validated before SQL generation/, fn ->
        Selecto.Builder.CaseExpression.build_case_expression(unvalidated_spec)
      end
    end
  end

  describe "integration with other Selecto features" do
    test "CASE with ORDER BY", %{selecto: selecto} do
      result =
        selecto
        # Select base fields first
        |> Selecto.select(["title", "rating"])
        |> Selecto.case_select(
          "rating",
          [
            {"G", "1"},
            {"PG", "2"},
            {"PG-13", "3"},
            {"R", "4"}
          ], else: "5", as: "rating_order")
        # Order by the original field instead of calculated field
        |> Selecto.order_by([{"rating", :asc}])
        # Limit results
        |> Selecto.filter([{"film_id", {:<, 15}}])
        |> Selecto.execute()

      assert {:ok, {results, _columns, _aliases}} = result
      assert length(results) > 0

      # Check that we have the expected columns
      [first_result | _] = results
      # title, rating, rating_order
      assert length(first_result) == 3
    end

    test "CASE with GROUP BY", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.case_when_select(
          [
            {[{"length", {:>, 120}}], "Long"},
            {[{"length", {:<, 90}}], "Short"}
          ], else: "Medium", as: "length_category")
        # Don't select the CASE alias separately
        |> Selecto.select([{:count, "*"}])
        # Group by the base field instead of calculated field
        |> Selecto.group_by(["length"])
        |> Selecto.execute()

      assert {:ok, {results, _columns, _aliases}} = result
      assert length(results) > 0

      # Check that we have the expected columns  
      [first_result | _] = results
      # length_category, film_count
      assert length(first_result) == 2

      # Verify all results have positive counts
      Enum.each(results, fn [_category, count] ->
        assert is_integer(count)
        assert count > 0
      end)
    end

    test "multiple CASE expressions in same query", %{selecto: selecto} do
      result =
        selecto
        # Select base fields first
        |> Selecto.select(["title"])
        |> Selecto.case_select(
          "rating",
          [
            {"G", "Family"},
            {"R", "Adult"}
          ], else: "General", as: "audience")
        |> Selecto.case_when_select(
          [
            {[{"length", {:>, 120}}], "Long"},
            {[{"length", {:<, 90}}], "Short"}
          ], else: "Medium", as: "duration")
        # Limit results
        |> Selecto.filter([{"film_id", {:<, 10}}])
        |> Selecto.execute()

      assert {:ok, {results, _columns, _aliases}} = result
      assert length(results) > 0

      # Check that we have the expected columns
      [first_result | _] = results
      # title, audience, duration
      assert length(first_result) == 3
    end
  end

  describe "edge cases" do
    test "CASE with NULL handling", %{selecto: selecto} do
      result =
        selecto
        # Select base fields first
        |> Selecto.select(["title", "rating"])
        |> Selecto.case_select(
          "rating",
          [
            {nil, "Unrated"},
            {"G", "General"}
          ], else: "Other", as: "rating_desc")
        # Limit results
        |> Selecto.filter([{"film_id", {:<, 10}}])
        |> Selecto.execute()

      assert {:ok, {_results, _columns, _aliases}} = result
      # This should not crash
    end

    test "CASE with complex filter conditions", %{selecto: selecto} do
      result =
        selecto
        # Select base fields first
        |> Selecto.select(["title"])
        |> Selecto.case_when_select(
          [
            {[
               {"rating", "R"},
               {"length", {:>, 120}},
               {"rental_rate", {:>, 3.50}}
             ], "Premium Adult"},
            {[
               {"rating", {:in, ["G", "PG"]}},
               {"rental_rate", {:<, 2.50}}
             ], "Budget Family"}
          ], else: "Standard", as: "film_tier")
        # Limit dataset
        |> Selecto.filter([{"film_id", {:<, 50}}])
        |> Selecto.execute()

      assert {:ok, {results, _columns, _aliases}} = result
      assert length(results) > 0

      # Check that we have the expected columns
      [first_result | _] = results
      # title, film_tier
      assert length(first_result) == 2
    end
  end
end
