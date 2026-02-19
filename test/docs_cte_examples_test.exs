defmodule DocsCteExamplesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  These tests demonstrate CTE (Common Table Expression) functionality in Selecto.
  They verify that CTEs can be added to queries using the actual Selecto API.
  """

  describe "Basic CTEs" do
    test "basic CTE can be added to a query" do
      # Create a basic selecto with proper structure
      selecto = create_base_selecto("customer")

      # Add a CTE
      result =
        selecto
        |> Selecto.with_cte("active_customers", fn ->
          create_base_selecto("customer")
          |> Map.put(:set, %{
            selected: ["customer_id", "first_name", "last_name", "email"],
            from: "customer",
            filter: [{"active", true}, {"created_at", {:>, "2023-01-01"}}]
          })
        end)

      # Verify CTE was added
      assert Map.has_key?(result.set, :ctes)
      assert length(result.set.ctes) == 1

      cte = hd(result.set.ctes)
      assert cte.name == "active_customers"
      assert cte.type == :normal
      assert is_function(cte.query_builder, 0)
    end

    test "CTE with aggregation can be created" do
      selecto = create_base_selecto("customer")

      # Create a CTE spec with aggregation
      cte_spec =
        Selecto.Advanced.CTE.create_cte("customer_stats", fn ->
          %{
            set: %{
              selected: [
                "customer_id",
                {:aggregate, :sum, "amount", as: "total_spent"},
                {:aggregate, :count, "*", as: "payment_count"},
                {:aggregate, :avg, "amount", as: "avg_payment"}
              ],
              group_by: ["customer_id"],
              from: "payment"
            },
            domain: %{},
            config: %{},
            source: %{}
          }
        end)

      # Add the CTE to the main query
      result = Selecto.with_ctes(selecto, [cte_spec])

      # Verify CTE was added
      assert Map.has_key?(result.set, :ctes)
      assert length(result.set.ctes) == 1

      cte = hd(result.set.ctes)
      assert cte.name == "customer_stats"
      assert cte.type == :normal
    end

    test "CTE with complex query structure" do
      selecto = create_base_selecto("customer")

      # Create a CTE that represents recent rentals
      result =
        selecto
        |> Selecto.with_cte("recent_rentals", fn ->
          %{
            set: %{
              selected: ["customer_id", "title", "rating", "rental_date"],
              from: "rental",
              filter: [{"rental_date", {:>, {:literal, "CURRENT_DATE - INTERVAL '30 days'"}}}],
              order_by: [{"rental_date", :desc}]
            },
            domain: %{},
            config: %{},
            source: %{}
          }
        end)

      # Verify CTE structure
      assert Map.has_key?(result.set, :ctes)
      assert length(result.set.ctes) == 1

      cte = hd(result.set.ctes)
      assert cte.name == "recent_rentals"
      assert cte.type == :normal
    end
  end

  describe "Multiple CTEs" do
    test "multiple independent CTEs can be added" do
      selecto = create_base_selecto("rental")

      # Create multiple CTE specifications
      cte1 =
        Selecto.Advanced.CTE.create_cte("high_value_customers", fn ->
          %{
            set: %{
              selected: ["customer_id", "first_name", "last_name"],
              from: "customer",
              group_by: ["customer_id", "first_name", "last_name"]
            },
            domain: %{},
            config: %{},
            source: %{}
          }
        end)

      cte2 =
        Selecto.Advanced.CTE.create_cte("popular_films", fn ->
          %{
            set: %{
              selected: ["film_id", "title", "rating"],
              from: "film",
              group_by: ["film_id", "title", "rating"]
            },
            domain: %{},
            config: %{},
            source: %{}
          }
        end)

      # Add multiple CTEs to the query
      result = Selecto.with_ctes(selecto, [cte1, cte2])

      # Verify both CTEs were added
      assert Map.has_key?(result.set, :ctes)
      assert length(result.set.ctes) == 2
      assert Enum.map(result.set.ctes, & &1.name) == ["high_value_customers", "popular_films"]
    end

    test "dependent CTEs can reference other CTEs" do
      selecto = create_base_selecto("rental")

      # Create CTEs that build on each other
      result =
        selecto
        |> Selecto.with_cte("base_data", fn ->
          %{
            set: %{
              selected: ["rental_id", "customer_id", "rental_date"],
              from: "rental",
              filter: [{"rental_date", {:>=, "2024-01-01"}}]
            },
            domain: %{},
            config: %{},
            source: %{}
          }
        end)
        |> Selecto.with_cte("daily_totals", fn ->
          # References base_data CTE
          %{
            set: %{
              selected: ["rental_date", {:aggregate, :count, "*", as: "daily_rentals"}],
              from: "base_data",
              group_by: ["rental_date"]
            },
            domain: %{},
            config: %{},
            source: %{}
          }
        end)

      # Verify CTEs were added
      assert Map.has_key?(result.set, :ctes)
      assert length(result.set.ctes) == 2
      assert Enum.map(result.set.ctes, & &1.name) == ["base_data", "daily_totals"]
    end
  end

  describe "Recursive CTEs" do
    test "basic recursive CTE for hierarchical data" do
      selecto = create_base_selecto("staff")

      result =
        selecto
        |> Selecto.with_recursive_cte("org_chart",
          # Base case: top-level employees
          base_query: fn ->
            %{
              set: %{
                selected: ["staff_id", "first_name", "last_name", {:literal, "0 AS level"}],
                from: "staff",
                # Manager ID 1 is top
                filter: [{"staff_id", 1}]
              },
              domain: %{},
              config: %{},
              source: %{}
            }
          end,
          # Recursive case
          recursive_query: fn _cte ->
            %{
              set: %{
                selected: [
                  "s.staff_id",
                  "s.first_name",
                  "s.last_name",
                  {:literal, "org_chart.level + 1"}
                ],
                from: "staff s",
                # Limit depth
                filter: [{"org_chart.level", {:<, 5}}]
              },
              domain: %{},
              config: %{},
              source: %{}
            }
          end
        )

      # Verify recursive CTE was added
      assert Map.has_key?(result.set, :ctes)
      assert length(result.set.ctes) == 1

      cte = hd(result.set.ctes)
      assert cte.name == "org_chart"
      assert cte.type == :recursive
      assert is_function(cte.base_query, 0)
      assert is_function(cte.recursive_query, 1)
    end

    test "recursive CTE generates proper SQL structure" do
      # Create a simple recursive CTE
      cte_spec =
        Selecto.Advanced.CTE.create_recursive_cte(
          "number_series",
          base_query: fn ->
            %{
              set: %{
                selected: [{:literal, "1 AS n"}],
                # No FROM clause for literal select
                from: nil,
                # No filters for base query
                filtered: [],
                # No GROUP BY
                group_by: [],
                # No ORDER BY
                order_by: [],
                # No LIMIT
                limit: nil,
                # No OFFSET
                offset: nil
              },
              domain: %{},
              config: %{
                # Add source_table
                source_table: nil,
                source: %{
                  table: nil,
                  fields: [],
                  columns: %{},
                  redact_fields: []
                },
                joins: %{},
                columns: %{}
              },
              source: %{
                table: nil,
                fields: [],
                columns: %{},
                redact_fields: []
              }
            }
          end,
          recursive_query: fn _cte_ref ->
            %{
              set: %{
                selected: [{:literal, "n + 1"}],
                from: "number_series",
                # Use filtered instead of filter
                filtered: [{"n", {:<, 10}}],
                # No GROUP BY
                group_by: [],
                # No ORDER BY
                order_by: [],
                # No LIMIT
                limit: nil,
                # No OFFSET
                offset: nil
              },
              domain: %{},
              config: %{
                # Add source_table
                source_table: "number_series",
                source: %{
                  table: "number_series",
                  fields: [:n],
                  columns: %{n: %{type: :integer}},
                  redact_fields: []
                },
                joins: %{},
                columns: %{"n" => %{name: "n", field: "n", requires_join: nil}}
              },
              source: %{
                table: "number_series",
                fields: [:n],
                columns: %{n: %{type: :integer}},
                redact_fields: []
              }
            }
          end
        )

      # Verify the spec
      assert cte_spec.type == :recursive
      assert cte_spec.name == "number_series"
      assert is_function(cte_spec.base_query, 0)
      assert is_function(cte_spec.recursive_query, 1)

      # Build CTE definition to verify it compiles
      {cte_iodata, params} = Selecto.Builder.CTE.build_cte_definition(cte_spec)
      {sql_string, _final_params} = Selecto.SQL.Params.finalize(cte_iodata)

      # Verify SQL structure
      assert sql_string =~ "number_series AS"
      assert sql_string =~ "UNION ALL"
      assert 10 in params
    end
  end

  # Helper to create a base selecto structure
  defp create_base_selecto(table) do
    %{
      set: %{
        selected: [],
        from: table
      },
      domain: %{},
      config: %{
        source: %{
          table: table,
          fields: [],
          columns: %{},
          redact_fields: []
        },
        joins: %{},
        columns: %{}
      },
      source: %{
        table: table,
        fields: [],
        columns: %{},
        redact_fields: []
      }
    }
  end
end
