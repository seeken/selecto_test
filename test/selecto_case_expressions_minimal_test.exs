defmodule SelectoCaseExpressionsMinimalTest do
  use SelectoTest.SelectoCase, async: false

  # Minimal tests for CASE expression functionality to validate core implementation

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

    # Simple film domain for testing CASE expressions
    domain = %{
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :length, :rating],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          length: %{type: :integer},
          rating: %{type: :string}
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

  describe "basic CASE functionality" do
    test "simple CASE SQL generation", %{selecto: selecto} do
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

      # Test SQL structure
      assert String.contains?(sql, "CASE rating")
      assert String.contains?(sql, "WHEN")
      assert String.contains?(sql, "THEN")
      assert String.contains?(sql, "ELSE")
      assert String.contains?(sql, "END AS rating_desc")

      # Parameters should be simple values
      assert is_list(params)
      assert length(params) > 0
    end

    test "searched CASE SQL generation", %{selecto: selecto} do
      {sql, _aliases, params} =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.case_when_select(
          [
            {[{"length", {:>, 120}}], "Long"}
          ], else: "Short", as: "length_desc")
        |> Selecto.gen_sql([])

      # Test SQL structure
      assert String.contains?(sql, "CASE")
      assert String.contains?(sql, "WHEN")
      assert String.contains?(sql, "THEN")
      assert String.contains?(sql, "ELSE")
      assert String.contains?(sql, "END AS length_desc")

      # Parameters should be present
      assert is_list(params)
      assert length(params) > 0
    end

    test "simple CASE execution", %{selecto: selecto} do
      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.case_select(
          "length",
          [
            {90, "Ninety"},
            {120, "OneHundredTwenty"}
          ], else: "Other", as: "length_desc")
        # Use exact value instead of comparison
        |> Selecto.filter([{"film_id", 1}])
        |> Selecto.execute()

      case result do
        {:ok, {results, _columns, _aliases}} ->
          assert length(results) > 0
          [first_result | _] = results
          # title and length_desc
          assert length(first_result) == 2

        {:error, error} ->
          flunk("CASE execution failed: #{inspect(error)}")
      end
    end
  end

  describe "CASE validation" do
    test "simple CASE requires column" do
      assert_raise Selecto.Advanced.CaseExpression.ValidationError,
                   ~r/Simple CASE expression must have a column/,
                   fn ->
                     Selecto.Advanced.CaseExpression.create_simple_case(nil, [{"G", "General"}])
                   end
    end

    test "searched CASE validates WHEN clauses" do
      assert_raise Selecto.Advanced.CaseExpression.ValidationError,
                   ~r/Searched CASE WHEN clauses must be/,
                   fn ->
                     Selecto.Advanced.CaseExpression.create_searched_case([{"invalid"}])
                   end
    end
  end
end
