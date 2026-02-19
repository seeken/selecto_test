defmodule DocsSubqueriesSubfiltersExamplesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  These tests demonstrate subqueries and subfilters functionality in Selecto.
  They have been updated to use the actual Selecto API.
  """

  alias Selecto.Builder.Sql

  # Helper to configure test Selecto instance
  defp configure_test_selecto(table) do
    # Build a proper domain configuration structure
    domain_config =
      case table do
        "actor" ->
          %{
            name: "Actor",
            source: %{
              source_table: "actor",
              primary_key: :actor_id,
              fields: [:actor_id, :first_name, :last_name],
              redact_fields: [],
              columns: %{
                actor_id: %{type: :integer},
                first_name: %{type: :string},
                last_name: %{type: :string}
              },
              associations: %{
                film_actors: %{
                  queryable: :film_actors,
                  field: :film_actors,
                  owner_key: :actor_id,
                  related_key: :actor_id
                }
              }
            },
            schemas: %{
              film_actors: %{
                source_table: "film_actor",
                primary_key: :film_id,
                fields: [:film_id, :actor_id],
                redact_fields: [],
                columns: %{
                  film_id: %{type: :integer},
                  actor_id: %{type: :integer}
                },
                associations: %{
                  film: %{
                    queryable: :film,
                    field: :film,
                    owner_key: :film_id,
                    related_key: :film_id
                  }
                }
              },
              film: %{
                source_table: "film",
                primary_key: :film_id,
                fields: [:film_id, :title, :release_year],
                redact_fields: [],
                columns: %{
                  film_id: %{type: :integer},
                  title: %{type: :string},
                  release_year: %{type: :integer}
                },
                associations: %{}
              }
            },
            joins: %{}
          }

        "film" ->
          %{
            name: "Film",
            source: %{
              source_table: "film",
              primary_key: :film_id,
              fields: [:film_id, :title],
              redact_fields: [],
              columns: %{
                film_id: %{type: :integer},
                title: %{type: :string}
              },
              associations: %{
                film_actors: %{
                  queryable: :film_actors,
                  field: :film_actors,
                  owner_key: :film_id,
                  related_key: :film_id
                }
              }
            },
            schemas: %{
              film_actors: %{
                source_table: "film_actor",
                primary_key: :actor_id,
                fields: [:film_id, :actor_id],
                redact_fields: [],
                columns: %{
                  film_id: %{type: :integer},
                  actor_id: %{type: :integer}
                },
                associations: %{}
              }
            },
            joins: %{}
          }

        "customer" ->
          %{
            name: "Customer",
            source: %{
              source_table: "customer",
              primary_key: :customer_id,
              fields: [:customer_id, :first_name, :last_name],
              redact_fields: [],
              columns: %{
                customer_id: %{type: :integer},
                first_name: %{type: :string},
                last_name: %{type: :string}
              },
              associations: %{
                orders: %{
                  queryable: :orders,
                  field: :orders,
                  owner_key: :customer_id,
                  related_key: :customer_id
                },
                payments: %{
                  queryable: :payments,
                  field: :payments,
                  owner_key: :customer_id,
                  related_key: :customer_id
                }
              }
            },
            schemas: %{
              orders: %{
                source_table: "orders",
                primary_key: :order_id,
                fields: [:order_id, :customer_id, :total, :order_date, :status],
                redact_fields: [],
                columns: %{
                  order_id: %{type: :integer},
                  customer_id: %{type: :integer},
                  total: %{type: :decimal},
                  order_date: %{type: :date},
                  status: %{type: :string}
                },
                associations: %{}
              },
              payments: %{
                source_table: "payments",
                primary_key: :payment_id,
                fields: [:payment_id, :customer_id, :amount],
                redact_fields: [],
                columns: %{
                  payment_id: %{type: :integer},
                  customer_id: %{type: :integer},
                  amount: %{type: :decimal}
                },
                associations: %{}
              }
            },
            joins: %{}
          }

        _ ->
          %{
            name: "Default",
            source: %{
              source_table: table,
              primary_key: :id,
              fields: [:id],
              redact_fields: [],
              columns: %{
                id: %{type: :integer}
              },
              associations: %{}
            },
            schemas: %{}
          }
      end

    Selecto.configure(domain_config, :test_connection)
  end

  describe "Subselect functionality" do
    test "subselect with JSON aggregation" do
      selecto = configure_test_selecto("actor")

      # Use Selecto.subselect for correlated subqueries
      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :film,
            fields: [:title, :release_year],
            format: :json_agg,
            alias: "films",
            filters: [],
            order_by: []
          }
        ])
        |> Selecto.select(["actor_id", "first_name", "last_name"])

      # The subselect should be included in the generated SQL
      {sql, _aliases, _params} = Sql.build(result, [])

      assert sql =~ "actor_id"
      assert sql =~ "first_name"
      assert sql =~ "last_name"
      # Subselect generates correlated subquery
      assert sql =~ ~r/select/i
      assert sql =~ "FROM film"
    end

    test "subselect with count aggregation" do
      selecto = configure_test_selecto("customer")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:order_id],
            format: :count,
            alias: "order_count",
            filters: [{"status", "completed"}],
            order_by: []
          }
        ])
        |> Selecto.select(["customer_id", "first_name", "last_name"])

      # The subselect should generate a COUNT subquery
      # Note: actual SQL generation may vary, but the structure should be present
      assert result.set[:subselected] != nil
      assert length(result.set[:subselected]) == 1
    end

    test "subselect with array aggregation" do
      selecto = configure_test_selecto("film")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :film_actors,
            fields: [:actor_id],
            format: :array_agg,
            alias: "actor_ids",
            filters: [],
            order_by: []
          }
        ])
        |> Selecto.select(["film_id", "title"])

      # Check that subselect was added
      assert result.set[:subselected] != nil
      assert length(result.set[:subselected]) == 1

      [subselect_config | _] = result.set[:subselected]
      assert subselect_config.format == :array_agg
      assert subselect_config.alias == "actor_ids"
    end

    test "multiple subselects" do
      selecto = configure_test_selecto("customer")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:order_id, :total],
            format: :json_agg,
            alias: "orders",
            filters: [],
            order_by: [{:desc, :order_date}]
          },
          %{
            target_schema: :payments,
            fields: [:payment_id, :amount],
            format: :json_agg,
            alias: "payments",
            filters: [],
            order_by: []
          }
        ])
        |> Selecto.select(["customer_id", "first_name", "last_name"])

      # Check that both subselects were added
      assert result.set[:subselected] != nil
      assert length(result.set[:subselected]) == 2

      [first_subselect, second_subselect] = result.set[:subselected]
      assert first_subselect.alias == "orders"
      assert second_subselect.alias == "payments"
    end
  end

  describe "Additional Subselect Features" do
    test "subselect with string aggregation" do
      selecto = configure_test_selecto("actor")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :film,
            fields: [:title],
            format: :string_agg,
            alias: "film_titles",
            separator: ", ",
            filters: [],
            order_by: [:title]
          }
        ])
        |> Selecto.select(["actor_id", "first_name", "last_name"])

      # Check that string_agg subselect was added
      assert result.set[:subselected] != nil
      [subselect_config | _] = result.set[:subselected]
      assert subselect_config.format == :string_agg
      assert subselect_config.separator == ", "
    end

    test "subselect with filters" do
      selecto = configure_test_selecto("customer")

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:order_id, :total],
            format: :json_agg,
            alias: "recent_orders",
            filters: [{"status", "completed"}, {"total", {:>, 100}}],
            order_by: [{:desc, :order_date}]
          }
        ])
        |> Selecto.select(["customer_id", "first_name", "last_name"])

      # Check that filters were included
      assert result.set[:subselected] != nil
      [subselect_config | _] = result.set[:subselected]
      assert length(subselect_config.filters) == 2
      assert {"status", "completed"} in subselect_config.filters
      assert {"total", {:>, 100}} in subselect_config.filters
    end
  end

  describe "Subselect with different configurations" do
    test "subselect field format validation" do
      selecto = configure_test_selecto("actor")

      # Test that various formats are accepted
      formats = [:json_agg, :array_agg, :string_agg, :count]

      Enum.each(formats, fn format ->
        result =
          selecto
          |> Selecto.subselect([
            %{
              target_schema: :film,
              fields: [:film_id],
              format: format,
              alias: "#{format}_result",
              filters: [],
              order_by: []
            }
          ])

        assert result.set[:subselected] != nil
        [subselect | _] = result.set[:subselected]
        assert subselect.format == format
      end)
    end

    test "subselect preserves original selecto structure" do
      selecto = configure_test_selecto("customer")

      original_keys = Map.keys(selecto)

      result =
        selecto
        |> Selecto.subselect([
          %{
            target_schema: :orders,
            fields: [:order_id],
            format: :count,
            alias: "order_count",
            filters: [],
            order_by: []
          }
        ])

      # Ensure all original keys are still present
      assert Map.keys(result) == original_keys

      # Ensure subselected field was added to set
      assert Map.has_key?(result.set, :subselected)
    end
  end
end
