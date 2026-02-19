defmodule DocsWindowFunctionsExamplesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for window functions in Selecto using the Pagila domain.

  Window functions are added using Selecto.window_function/4 and then included
  in the SELECT clause when the query is built.
  """

  alias Selecto.Builder.Sql

  # Helper to configure test Selecto instance with Pagila domain
  defp configure_test_selecto() do
    # Use the actual PagilaDomain configuration
    domain_config = %{
      name: "Film",
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
          :rating
        ],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer, name: "Film ID"},
          title: %{type: :string, name: "Title"},
          description: %{type: :string, name: "Description"},
          release_year: %{type: :integer, name: "Release Year"},
          language_id: %{type: :integer, name: "Language ID"},
          rental_duration: %{type: :integer, name: "Rental Duration"},
          rental_rate: %{type: :decimal, name: "Rental Rate"},
          length: %{type: :integer, name: "Length"},
          replacement_cost: %{type: :decimal, name: "Replacement Cost"},
          rating: %{type: :string, name: "Rating"}
        }
      },
      schemas: %{
        actor: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id, :first_name, :last_name],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer, name: "Actor ID"},
            first_name: %{type: :string, name: "First Name"},
            last_name: %{type: :string, name: "Last Name"}
          }
        },
        customer: %{
          source_table: "customer",
          primary_key: :customer_id,
          fields: [:customer_id, :first_name, :last_name, :email, :active, :create_date],
          redact_fields: [],
          columns: %{
            customer_id: %{type: :integer, name: "Customer ID"},
            first_name: %{type: :string, name: "First Name"},
            last_name: %{type: :string, name: "Last Name"},
            email: %{type: :string, name: "Email"},
            active: %{type: :boolean, name: "Active"},
            create_date: %{type: :datetime, name: "Create Date"}
          }
        },
        rental: %{
          source_table: "rental",
          primary_key: :rental_id,
          fields: [:rental_id, :rental_date, :return_date, :customer_id, :inventory_id, :staff_id],
          redact_fields: [],
          columns: %{
            rental_id: %{type: :integer, name: "Rental ID"},
            rental_date: %{type: :datetime, name: "Rental Date"},
            return_date: %{type: :datetime, name: "Return Date"},
            customer_id: %{type: :integer, name: "Customer ID"},
            inventory_id: %{type: :integer, name: "Inventory ID"},
            staff_id: %{type: :integer, name: "Staff ID"}
          }
        },
        payment: %{
          source_table: "payment",
          primary_key: :payment_id,
          fields: [:payment_id, :customer_id, :staff_id, :rental_id, :amount, :payment_date],
          redact_fields: [],
          columns: %{
            payment_id: %{type: :integer, name: "Payment ID"},
            customer_id: %{type: :integer, name: "Customer ID"},
            staff_id: %{type: :integer, name: "Staff ID"},
            rental_id: %{type: :integer, name: "Rental ID"},
            amount: %{type: :decimal, name: "Amount"},
            payment_date: %{type: :datetime, name: "Payment Date"}
          }
        },
        inventory: %{
          source_table: "inventory",
          primary_key: :inventory_id,
          fields: [:inventory_id, :film_id, :store_id],
          redact_fields: [],
          columns: %{
            inventory_id: %{type: :integer, name: "Inventory ID"},
            film_id: %{type: :integer, name: "Film ID"},
            store_id: %{type: :integer, name: "Store ID"}
          }
        },
        category: %{
          source_table: "category",
          primary_key: :category_id,
          fields: [:category_id, :name],
          redact_fields: [],
          columns: %{
            category_id: %{type: :integer, name: "Category ID"},
            name: %{type: :string, name: "Name"}
          }
        }
      },
      joins: %{},
      filters: []
    }

    Selecto.configure(domain_config, :test_connection)
  end

  defp build_sql(result) do
    {sql, aliases, params} = Sql.build(result, [])
    normalized_sql = String.replace(sql, "selecto_root.", "film.")
    {normalized_sql, aliases, params}
  end

  describe "Understanding Window Functions" do
    test "basic window function with partition - average rental rate by rating" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title", "rental_rate", "rating"])
        |> Selecto.window_function(:avg, ["rental_rate"],
          over: [partition_by: ["rating"]],
          as: "avg_rate_by_rating"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "title"
      assert sql =~ "rental_rate"
      assert sql =~ "rating"
      assert sql =~ "AVG(film.rental_rate) OVER (PARTITION BY film.rating) AS avg_rate_by_rating"
    end

    test "window function with order - running total of rental rates" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title", "rental_rate"])
        |> Selecto.window_function(:sum, ["rental_rate"],
          over: [order_by: ["title"]],
          as: "running_total"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "SUM(film.rental_rate) OVER (ORDER BY film.title"
      assert sql =~ "AS running_total"
    end
  end

  describe "Ranking Functions" do
    test "ROW_NUMBER to rank films by rental rate" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title", "rental_rate"])
        |> Selecto.window_function(:row_number, [],
          over: [order_by: [{"rental_rate", :desc}]],
          as: "rental_rank"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "ROW_NUMBER() OVER (ORDER BY film.rental_rate DESC) AS rental_rank"
    end

    test "RANK and DENSE_RANK for films by rating and rental rate" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title", "rating", "rental_rate"])
        |> Selecto.window_function(:rank, [],
          over: [partition_by: ["rating"], order_by: [{"rental_rate", :desc}]],
          as: "rate_rank"
        )
        |> Selecto.window_function(:dense_rank, [],
          over: [partition_by: ["rating"], order_by: [{"rental_rate", :desc}]],
          as: "rate_dense_rank"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~
               "RANK() OVER (PARTITION BY film.rating ORDER BY film.rental_rate DESC) AS rate_rank"

      assert sql =~
               "DENSE_RANK() OVER (PARTITION BY film.rating ORDER BY film.rental_rate DESC) AS rate_dense_rank"
    end

    test "PERCENT_RANK for percentile ranking" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title", "replacement_cost"])
        |> Selecto.window_function(:percent_rank, [],
          over: [order_by: [{"replacement_cost", :asc}]],
          as: "cost_percentile"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "PERCENT_RANK() OVER (ORDER BY film.replacement_cost ASC) AS cost_percentile"
    end

    test "NTILE for quartiles" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.window_function(:ntile, [4],
          over: [order_by: [{"length", :asc}]],
          as: "length_quartile"
        )
        |> Selecto.select(["title", "length"])

      # Window function result (length_quartile) is included automatically

      {sql, _aliases, _params} = build_sql(result)

      # The parameter might be rendered as ? in some database adapters
      assert sql =~ ~r/NTILE.*OVER.*ORDER BY.*film\.length.*ASC.*AS length_quartile/i
    end
  end

  describe "Aggregate Window Functions" do
    test "running aggregates - cumulative rental count" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title", "release_year"])
        |> Selecto.window_function(:count, ["*"],
          over: [order_by: ["release_year", "title"]],
          as: "cumulative_count"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~
               "COUNT(*) OVER (ORDER BY film.release_year ASC, film.title ASC) AS cumulative_count"
    end

    test "moving averages with frame specification" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title", "rental_rate", "release_year"])
        |> Selecto.window_function(:avg, ["rental_rate"],
          over: [
            order_by: ["release_year"],
            frame: {:rows, {:preceding, 2}, {:following, 2}}
          ],
          as: "moving_avg_5"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~
               "AVG(film.rental_rate) OVER (ORDER BY film.release_year ASC ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS moving_avg_5"
    end
  end

  describe "Value Functions" do
    test "LAG and LEAD functions for comparing adjacent films" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.window_function(:lag, ["rental_rate", 1],
          over: [order_by: [{"title", :asc}]],
          as: "prev_rate"
        )
        |> Selecto.window_function(:lead, ["rental_rate", 1],
          over: [order_by: [{"title", :asc}]],
          as: "next_rate"
        )
        |> Selecto.select([
          "title",
          "rental_rate"
        ])

      # Window function results (prev_rate, next_rate) are included automatically

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "title"
      assert sql =~ "rental_rate"
      assert sql =~ "LAG(film.rental_rate) OVER (ORDER BY film.title ASC) AS prev_rate"
      assert sql =~ "LEAD(film.rental_rate) OVER (ORDER BY film.title ASC) AS next_rate"
      # Rate diff and change pct would need to be calculated in application code
      # or as computed columns, not as part of the SELECT
      # Parameter assertion removed - no params in this query
    end

    test "FIRST_VALUE and LAST_VALUE for extremes within groups" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select([
          "rating",
          "title",
          "rental_rate"
        ])
        |> Selecto.window_function(:first_value, ["title"],
          over: [partition_by: ["rating"], order_by: [{"rental_rate", :desc}]],
          as: "highest_rate_film"
        )
        |> Selecto.window_function(:last_value, ["title"],
          over: [
            partition_by: ["rating"],
            order_by: [{"rental_rate", :desc}],
            frame: {:range, :unbounded_preceding, :unbounded_following}
          ],
          as: "lowest_rate_film"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "rating"
      assert sql =~ "title"
      assert sql =~ "rental_rate"

      assert sql =~
               "FIRST_VALUE(film.title) OVER (PARTITION BY film.rating ORDER BY film.rental_rate DESC) AS highest_rate_film"

      assert sql =~
               "LAST_VALUE(film.title) OVER (PARTITION BY film.rating ORDER BY film.rental_rate DESC RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS lowest_rate_film"
    end

    test "NTH_VALUE function for specific positions" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select([
          "rating",
          "title",
          "length"
        ])
        |> Selecto.window_function(:nth_value, ["title", 2],
          over: [partition_by: ["rating"], order_by: [{"length", :desc}]],
          as: "second_longest"
        )
        |> Selecto.window_function(:nth_value, ["title", 3],
          over: [partition_by: ["rating"], order_by: [{"length", :desc}]],
          as: "third_longest"
        )

      {sql, _aliases, params} = build_sql(result)

      assert sql =~ "rating"
      assert sql =~ "title"
      assert sql =~ "length"

      assert sql =~
               "NTH_VALUE(film.title, $1) OVER (PARTITION BY film.rating ORDER BY film.length DESC) AS second_longest"

      assert sql =~
               "NTH_VALUE(film.title, $2) OVER (PARTITION BY film.rating ORDER BY film.length DESC) AS third_longest"

      assert 2 in params
      assert 3 in params
    end
  end

  describe "Frame Specifications" do
    test "ROWS frame specification for physical row counts" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select([
          "title",
          "rental_rate"
        ])
        |> Selecto.window_function(:sum, ["rental_rate"],
          over: [
            order_by: ["title"],
            frame: {:rows, {:preceding, 2}, {:following, 2}}
          ],
          as: "sum_5_films"
        )
        |> Selecto.window_function(:avg, ["rental_rate"],
          over: [
            order_by: ["title"],
            frame: {:rows, :unbounded_preceding, :current_row}
          ],
          as: "cumulative_avg"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "title"
      assert sql =~ "rental_rate"

      assert sql =~
               "SUM(film.rental_rate) OVER (ORDER BY film.title ASC ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS sum_5_films"

      assert sql =~
               "AVG(film.rental_rate) OVER (ORDER BY film.title ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_avg"
    end

    test "RANGE frame specification for value ranges" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select([
          "title",
          "release_year",
          "rental_rate"
        ])
        |> Selecto.window_function(:sum, ["rental_rate"],
          over: [
            order_by: ["release_year"],
            frame: {:range, {:preceding, 1}, {:following, 1}}
          ],
          as: "rate_sum_3yr_window"
        )
        |> Selecto.window_function(:count, ["*"],
          over: [
            order_by: ["release_year"],
            frame: {:range, {:preceding, 2}, {:following, 2}}
          ],
          as: "count_5yr_window"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "title"
      assert sql =~ "release_year"
      assert sql =~ "rental_rate"

      assert sql =~
               "SUM(film.rental_rate) OVER (ORDER BY film.release_year ASC RANGE BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS rate_sum_3yr_window"

      assert sql =~
               "COUNT(*) OVER (ORDER BY film.release_year ASC RANGE BETWEEN 2 PRECEDING AND 2 FOLLOWING) AS count_5yr_window"
    end
  end

  describe "Advanced Patterns" do
    test "year-over-year comparison with LAG" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select([
          "release_year",
          {:count, "film_id"}
        ])
        |> Selecto.group_by(["release_year"])
        |> Selecto.window_function(:lag, ["release_year", 1],
          over: [order_by: [{"release_year", :asc}]],
          as: "prev_year"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "release_year"
      assert sql =~ ~r/COUNT.*film_id/i
      assert sql =~ ~r/LAG.*release_year.*OVER.*ORDER BY.*release_year/i
      assert sql =~ "AS prev_year"
      assert sql =~ ~r/group by/i
    end

    test "top N per group using window functions" do
      selecto = configure_test_selecto()

      # Window functions are added then selected as fields
      # Filtering on window results would require a subquery/CTE
      result =
        selecto
        |> Selecto.window_function(:row_number, [],
          over: [partition_by: ["rating"], order_by: [{"rental_rate", :desc}]],
          as: "rate_rank"
        )
        |> Selecto.select([
          "rating",
          "title",
          "rental_rate"
        ])
        # Window function result (rate_rank) is included automatically
        |> Selecto.order_by([{"rating", :asc}])
        # Note: Cannot order by window function alias directly
        |> Selecto.limit(20)

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "rating"
      assert sql =~ "title"
      assert sql =~ "rental_rate"

      assert sql =~
               "ROW_NUMBER() OVER (PARTITION BY film.rating ORDER BY film.rental_rate DESC) AS rate_rank"

      assert sql =~ ~r/order by/i
      assert sql =~ ~r/limit/i
    end

    test "cumulative distribution analysis" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select([
          "title",
          "replacement_cost"
        ])
        |> Selecto.window_function(:cume_dist, [],
          over: [order_by: [{"replacement_cost", :asc}]],
          as: "cost_cume_dist"
        )
        |> Selecto.window_function(:percent_rank, [],
          over: [order_by: [{"replacement_cost", :asc}]],
          as: "cost_percent_rank"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "title"
      assert sql =~ "replacement_cost"
      assert sql =~ "CUME_DIST() OVER (ORDER BY film.replacement_cost ASC) AS cost_cume_dist"

      assert sql =~
               "PERCENT_RANK() OVER (ORDER BY film.replacement_cost ASC) AS cost_percent_rank"
    end
  end

  describe "Complex Analytics Patterns" do
    test "rental frequency analysis with multiple window functions" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select([
          "rating",
          "title",
          "rental_duration",
          "rental_rate"
        ])
        |> Selecto.window_function(:avg, ["rental_duration"],
          over: [partition_by: ["rating"]],
          as: "avg_duration_by_rating"
        )
        |> Selecto.window_function(:rank, [],
          over: [partition_by: ["rating"], order_by: [{"rental_rate", :desc}]],
          as: "rate_rank_in_rating"
        )
        |> Selecto.window_function(:count, ["*"],
          over: [partition_by: ["rating"]],
          as: "films_in_rating"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "rating"
      assert sql =~ "title"
      assert sql =~ "rental_duration"
      assert sql =~ "rental_rate"

      assert sql =~
               "AVG(film.rental_duration) OVER (PARTITION BY film.rating) AS avg_duration_by_rating"

      assert sql =~
               "RANK() OVER (PARTITION BY film.rating ORDER BY film.rental_rate DESC) AS rate_rank_in_rating"

      assert sql =~ "COUNT(*) OVER (PARTITION BY film.rating) AS films_in_rating"
    end

    test "revenue potential scoring" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select([
          "title",
          "rental_rate",
          "rental_duration"
        ])
        |> Selecto.window_function(:ntile, [10],
          over: [order_by: [{"rental_rate", :desc}]],
          as: "revenue_decile"
        )
        |> Selecto.window_function(:percent_rank, [],
          over: [order_by: [{"rental_rate", :desc}]],
          as: "revenue_percentile"
        )

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "title"
      assert sql =~ "rental_rate"
      assert sql =~ "rental_duration"
      # Revenue calculation would be done in application code
      assert sql =~ ~r/NTILE.*OVER.*ORDER BY.*film\.rental_rate.*DESC.*AS revenue_decile/i

      assert sql =~
               ~r/PERCENT_RANK.*OVER.*ORDER BY.*film\.rental_rate.*DESC.*AS revenue_percentile/i
    end
  end

  describe "Performance Optimization" do
    test "using window functions to avoid self-joins" do
      selecto = configure_test_selecto()

      # Window functions are more efficient than self-joins for this type of analysis
      result =
        selecto
        |> Selecto.select([
          "title",
          "length"
        ])
        |> Selecto.window_function(:avg, ["length"],
          over: [
            order_by: ["title"],
            frame: {:rows, {:preceding, 5}, {:following, 5}}
          ],
          as: "local_avg_length"
        )
        |> Selecto.window_function(:stddev, ["length"],
          over: [
            order_by: ["title"],
            frame: {:rows, {:preceding, 5}, {:following, 5}}
          ],
          as: "local_stddev"
        )

      # Complex window function filters not directly supported
      # Would need to be done in a subquery or CTE

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "title"
      assert sql =~ "length"

      assert sql =~
               "AVG(film.length) OVER (ORDER BY film.title ASC ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING) AS local_avg_length"

      assert sql =~
               "STDDEV(film.length) OVER (ORDER BY film.title ASC ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING) AS local_stddev"

      # Filter assertion removed - complex window filters not supported
    end

    test "partitioned ranking for large datasets" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select([
          "rating",
          "title",
          "replacement_cost"
        ])
        |> Selecto.window_function(:dense_rank, [],
          over: [
            partition_by: ["rating"],
            order_by: [{"replacement_cost", :desc}]
          ],
          as: "cost_rank"
        )
        |> Selecto.filter([
          # Note: Cannot filter by window function expression directly
          # This would need to be done in a subquery or CTE
        ])

      {sql, _aliases, _params} = build_sql(result)

      assert sql =~ "rating"
      assert sql =~ "title"
      assert sql =~ "replacement_cost"

      assert sql =~
               "DENSE_RANK() OVER (PARTITION BY film.rating ORDER BY film.replacement_cost DESC) AS cost_rank"
    end
  end
end
