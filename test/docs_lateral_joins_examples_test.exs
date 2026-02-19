defmodule DocsLateralJoinsExamplesTest do
  use ExUnit.Case, async: true
  import SelectoTest.TestHelpers

  @moduledoc """
  These tests demonstrate LATERAL join functionality in Selecto.
  They have been updated to use the actual Selecto API.
  """

  describe "Basic LATERAL Joins" do
    test "simple correlated subquery - recent orders per customer" do
      selecto = configure_test_selecto("customer")
      
      # Add a lateral join with correlated subquery
      result = 
        selecto
        |> Selecto.select(["name"])
        |> Selecto.lateral_join(
            :left,
            fn _base ->
              # Return a minimal selecto query for the lateral subquery
              %{
                set: %{
                  selected: ["order_id", "order_date", "total"],
                  from: "orders",
                  filtered: [{"customer_id", {:ref, "customer.customer_id"}}],
                  group_by: [],
                  order_by: [{"order_date", :desc}],
                  limit: 3,
                  offset: nil
                },
                domain: %{},
                config: %{
                  source_table: "orders",
                  source: %{
                    table: "orders",
                    fields: [:order_id, :order_date, :total, :customer_id],
                    columns: %{
                      order_id: %{type: :integer},
                      order_date: %{type: :date},
                      total: %{type: :decimal},
                      customer_id: %{type: :integer}
                    },
                    redact_fields: []
                  },
                  joins: %{},
                  columns: %{}
                },
                source: %{
                  table: "orders",
                  fields: [:order_id, :order_date, :total, :customer_id],
                  columns: %{
                    order_id: %{type: :integer},
                    order_date: %{type: :date},
                    total: %{type: :decimal},
                    customer_id: %{type: :integer}
                  },
                  redact_fields: []
                }
              }
            end,
            "recent_orders"
          )
      
      # Verify lateral join was added
      assert Map.has_key?(result.set, :lateral_joins)
      assert length(result.set.lateral_joins) == 1
      
      lateral = hd(result.set.lateral_joins)
      assert lateral.alias == "recent_orders"
      assert lateral.join_type == :left
      assert is_function(lateral.subquery_builder, 1)
    end

    test "lateral join with aggregation" do
      selecto = configure_test_selecto("film")
      
      result = 
        selecto
        |> Selecto.select(["title", "release_year"])
        |> Selecto.lateral_join(
            :left,
            fn _base ->
              %{
                set: %{
                  selected: [
                    {:aggregate, :count, "*", as: "total_rentals"},
                    {:aggregate, :sum, "amount", as: "total_revenue"}
                  ],
                  from: "rental",
                  filtered: [{"film_id", {:ref, "film.film_id"}}],
                  group_by: [],
                  order_by: [],
                  limit: nil,
                  offset: nil
                },
                domain: %{},
                config: %{
                  source_table: "rental",
                  source: %{
                    table: "rental",
                    fields: [:rental_id, :film_id, :amount],
                    columns: %{
                      rental_id: %{type: :integer},
                      film_id: %{type: :integer},
                      amount: %{type: :decimal}
                    },
                    redact_fields: []
                  },
                  joins: %{},
                  columns: %{}
                },
                source: %{
                  table: "rental",
                  fields: [:rental_id, :film_id, :amount],
                  columns: %{
                    rental_id: %{type: :integer},
                    film_id: %{type: :integer},
                    amount: %{type: :decimal}
                  },
                  redact_fields: []
                }
              }
            end,
            "rental_stats"
          )
      
      # Verify lateral join was added
      assert Map.has_key?(result.set, :lateral_joins)
      assert length(result.set.lateral_joins) == 1
      
      lateral = hd(result.set.lateral_joins)
      assert lateral.alias == "rental_stats"
      assert lateral.join_type == :left
    end

    test "lateral join with table function" do
      selecto = configure_test_selecto("film")
      
      # Add a lateral join using unnest table function
      result = 
        selecto
        |> Selecto.select(["title"])
        |> Selecto.lateral_join(
            :inner,
            {:unnest, "special_features"},
            "features",
            []
          )
      
      # Verify lateral join was added
      assert Map.has_key?(result.set, :lateral_joins)
      assert length(result.set.lateral_joins) == 1
      
      lateral = hd(result.set.lateral_joins)
      assert lateral.alias == "features"
      assert lateral.join_type == :inner
      assert lateral.table_function == {:unnest, "special_features"}
    end
  end

  describe "LATERAL Join SQL Generation" do
    test "lateral join generates correct SQL structure" do
      # Create lateral join spec directly
      lateral_spec = Selecto.Advanced.LateralJoin.create_lateral_join(
        :left,
        fn _base ->
          %{
            set: %{
              selected: ["rental_id", "rental_date"],
              from: "rental",
              filtered: [{"customer_id", {:ref, "customer.customer_id"}}],
              group_by: [],
              order_by: [{"rental_date", :desc}],
              limit: 5,
              offset: nil
            },
            domain: %{},
            config: %{
              source_table: "rental",
              source: %{
                table: "rental",
                fields: [:rental_id, :rental_date, :customer_id],
                columns: %{
                  rental_id: %{type: :integer},
                  rental_date: %{type: :timestamp},
                  customer_id: %{type: :integer}
                },
                redact_fields: []
              },
              joins: %{},
              columns: %{}
            },
            source: %{
              table: "rental",
              fields: [:rental_id, :rental_date, :customer_id],
              columns: %{
                rental_id: %{type: :integer},
                rental_date: %{type: :timestamp},
                customer_id: %{type: :integer}
              },
              redact_fields: []
            }
          }
        end,
        "recent_rentals"
      )
      
      # Build lateral join SQL
      {sql_iodata, params} = Selecto.Builder.LateralJoin.build_lateral_join(lateral_spec)
      
      {sql_string, finalized_params} =
        Selecto.SQL.Params.finalize(sql_iodata, adapter: Selecto.DB.PostgreSQL)
      
      # Verify SQL structure
      assert sql_string =~ "LEFT JOIN LATERAL"
      assert sql_string =~ "recent_rentals"
      assert sql_string =~ "ON"
      
      # Check that params contains the correlation reference
      assert {:ref, "customer.customer_id"} in params or {:ref, "customer.customer_id"} in finalized_params
    end

    test "table function lateral join generates correct SQL" do
      # Create lateral join spec with table function
      lateral_spec = Selecto.Advanced.LateralJoin.create_lateral_join(
        :inner,
        {:unnest, "array_column"},
        "elements"
      )
      
      # Build lateral join SQL
      {sql_iodata, _params} = Selecto.Builder.LateralJoin.build_lateral_join(lateral_spec)
      
      {sql_string, _finalized_params} =
        Selecto.SQL.Params.finalize(sql_iodata, adapter: Selecto.DB.PostgreSQL)
      
      # Verify SQL structure
      assert sql_string =~ "INNER JOIN LATERAL"
      assert sql_string =~ "UNNEST"
      assert sql_string =~ "array_column"
      assert sql_string =~ "elements"
      assert sql_string =~ "ON true"
    end
  end

  describe "Multiple LATERAL Joins" do
    test "multiple lateral joins can be added" do
      selecto = configure_test_selecto("customer")
      
      # Add multiple lateral joins
      result = 
        selecto
        |> Selecto.lateral_join(
            :left,
            fn _base ->
              %{
                set: %{
                  selected: ["order_id"],
                  from: "orders",
                  filtered: [{"customer_id", {:ref, "customer.customer_id"}}],
                  group_by: [],
                  order_by: [],
                  limit: 5,
                  offset: nil
                },
                domain: %{},
                config: %{
                  source_table: "orders",
                  source: %{
                    table: "orders",
                    fields: [:order_id, :customer_id],
                    columns: %{
                      order_id: %{type: :integer},
                      customer_id: %{type: :integer}
                    },
                    redact_fields: []
                  },
                  joins: %{},
                  columns: %{}
                },
                source: %{
                  table: "orders",
                  fields: [:order_id, :customer_id],
                  columns: %{
                    order_id: %{type: :integer},
                    customer_id: %{type: :integer}
                  },
                  redact_fields: []
                }
              }
            end,
            "recent_orders"
          )
        |> Selecto.lateral_join(
            :left,
            fn _base ->
              %{
                set: %{
                  selected: [{:aggregate, :count, "*", as: "payment_count"}],
                  from: "payment",
                  filtered: [{"customer_id", {:ref, "customer.customer_id"}}],
                  group_by: [],
                  order_by: [],
                  limit: nil,
                  offset: nil
                },
                domain: %{},
                config: %{
                  source_table: "payment",
                  source: %{
                    table: "payment",
                    fields: [:payment_id, :customer_id],
                    columns: %{
                      payment_id: %{type: :integer},
                      customer_id: %{type: :integer}
                    },
                    redact_fields: []
                  },
                  joins: %{},
                  columns: %{}
                },
                source: %{
                  table: "payment",
                  fields: [:payment_id, :customer_id],
                  columns: %{
                    payment_id: %{type: :integer},
                    customer_id: %{type: :integer}
                  },
                  redact_fields: []
                }
              }
            end,
            "payment_stats"
          )
      
      # Verify both lateral joins were added
      assert Map.has_key?(result.set, :lateral_joins)
      assert length(result.set.lateral_joins) == 2
      
      [lateral1, lateral2] = result.set.lateral_joins
      assert lateral1.alias == "recent_orders"
      assert lateral2.alias == "payment_stats"
    end
  end

  # Helper to create a base selecto structure
  # Removed create_base_selecto - using configure_test_selecto from TestHelpers instead
end
