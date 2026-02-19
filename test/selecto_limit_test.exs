defmodule SelectoLimitTest do
  use ExUnit.Case, async: true

  describe "limit and offset functionality" do
    test "adds LIMIT clause to query" do
      domain = get_test_domain()
      selecto = Selecto.configure(domain, [], validate: false)

      result =
        selecto
        |> Selecto.select(["title", "rating"])
        |> Selecto.limit(10)

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ "limit 10"
    end

    test "adds OFFSET clause to query" do
      domain = get_test_domain()
      selecto = Selecto.configure(domain, [], validate: false)

      result =
        selecto
        |> Selecto.select(["title", "rating"])
        |> Selecto.offset(20)

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ "offset 20"
    end

    test "adds both LIMIT and OFFSET for pagination" do
      domain = get_test_domain()
      selecto = Selecto.configure(domain, [], validate: false)

      result =
        selecto
        |> Selecto.select(["title", "rating"])
        |> Selecto.limit(10)
        |> Selecto.offset(30)

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ "limit 10"
      assert sql =~ "offset 30"
    end

    test "LIMIT and OFFSET work with ORDER BY" do
      domain = get_test_domain()
      selecto = Selecto.configure(domain, [], validate: false)

      result =
        selecto
        |> Selecto.select(["title", "rating"])
        |> Selecto.order_by([{"title", :asc}])
        |> Selecto.limit(5)
        |> Selecto.offset(10)

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      # Check that clauses appear in correct SQL order
      assert sql =~ "order by"
      assert sql =~ "limit 5"
      assert sql =~ "offset 10"

      # Verify order: ORDER BY should come before LIMIT
      order_by_pos = :binary.match(sql, "order by") |> elem(0)
      limit_pos = :binary.match(sql, "limit 5") |> elem(0)
      assert order_by_pos < limit_pos
    end

    test "LIMIT and OFFSET work with WHERE and GROUP BY" do
      domain = get_test_domain()
      selecto = Selecto.configure(domain, [], validate: false)

      result =
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.filter([{"rating", "PG"}])
        |> Selecto.group_by(["rating"])
        |> Selecto.order_by([{"rating", :desc}])
        |> Selecto.limit(3)

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ "where"
      assert sql =~ "group by"
      assert sql =~ "order by"
      assert sql =~ "limit 3"
    end
  end

  defp get_test_domain do
    %{
      name: "Film",
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :rating],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          rating: %{type: :string}
        },
        associations: %{}
      },
      schemas: %{},
      joins: %{}
    }
  end
end
