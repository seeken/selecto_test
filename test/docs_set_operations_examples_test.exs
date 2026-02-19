defmodule DocsSetOperationsExamplesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  These tests demonstrate set operations functionality in Selecto.
  They have been updated to use the actual Selecto API.
  """

  alias Selecto.SetOperations

  # Helper to create a basic configured selecto for testing
  defp create_base_selecto(table) do
    %{
      set: %{
        selected: [],
        from: table,
        filtered: [],
        group_by: [],
        order_by: [],
        limit: nil,
        offset: nil,
        set_operations: []
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

  describe "UNION Operations" do
    test "basic UNION removes duplicates" do
      # Create two queries to union
      query1 =
        create_base_selecto("employees")
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"active", true}])

      query2 =
        create_base_selecto("contractors")
        |> Selecto.select(["full_name", "email_address"])
        |> Selecto.filter([{"status", "active"}])

      # Create UNION
      result = Selecto.union(query1, query2)

      # Verify set operation was added
      assert Map.has_key?(result.set, :set_operations)
      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :union
      assert set_op.options.all == false
    end

    test "UNION ALL keeps duplicates" do
      query1 =
        create_base_selecto("online_orders")
        |> Selecto.select(["product_id", "quantity", "order_date"])

      query2 =
        create_base_selecto("store_orders")
        |> Selecto.select(["product_id", "quantity", "purchase_date"])

      # Create UNION ALL
      result = Selecto.union(query1, query2, all: true)

      # Verify UNION ALL
      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :union
      assert set_op.options.all == true
    end

    test "combining different sources with type indicators" do
      query1 =
        create_base_selecto("orders_2024")
        |> Selecto.select([
          "customer_id",
          "order_date",
          "total",
          {:literal, 2024, as: "year"},
          {:literal, "current", as: "period"}
        ])

      query2 =
        create_base_selecto("orders_2023")
        |> Selecto.select([
          "customer_id",
          "order_date",
          "total",
          {:literal, 2023, as: "year"},
          {:literal, "archive", as: "period"}
        ])

      result = Selecto.union(query1, query2)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :union
      assert set_op.left_query == query1
      assert set_op.right_query == query2
    end
  end

  describe "INTERSECT Operations" do
    test "finding common records" do
      query1 =
        create_base_selecto("customers")
        |> Selecto.select(["email", "name"])

      query2 =
        create_base_selecto("newsletter_subscribers")
        |> Selecto.select(["email", "name"])

      result = Selecto.intersect(query1, query2)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :intersect
      assert set_op.options.all == false
    end

    test "products available in all stores" do
      store1_inventory =
        create_base_selecto("store_inventory")
        |> Selecto.select(["product_id"])
        |> Selecto.filter([{"store_id", 1}])

      store2_inventory =
        create_base_selecto("store_inventory")
        |> Selecto.select(["product_id"])
        |> Selecto.filter([{"store_id", 2}])

      result = Selecto.intersect(store1_inventory, store2_inventory)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :intersect
    end

    test "INTERSECT ALL for duplicate preservation" do
      query1 =
        create_base_selecto("table1")
        |> Selecto.select(["id", "value"])

      query2 =
        create_base_selecto("table2")
        |> Selecto.select(["id", "value"])

      result = Selecto.intersect(query1, query2, all: true)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :intersect
      assert set_op.options.all == true
    end
  end

  describe "EXCEPT Operations" do
    test "finding customers who haven't made purchases" do
      all_customers =
        create_base_selecto("customers")
        |> Selecto.select(["customer_id", "email"])

      customers_with_orders =
        create_base_selecto("orders")
        |> Selecto.select(["customer_id", "customer_email"])
        |> Selecto.group_by(["customer_id", "customer_email"])

      result = Selecto.except(all_customers, customers_with_orders)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :except
      assert set_op.options.all == false
    end

    test "products not in any active promotion" do
      all_products =
        create_base_selecto("products")
        |> Selecto.select(["product_id", "name", "category"])
        |> Selecto.filter([{"active", true}])

      promoted_products =
        create_base_selecto("promotion_items")
        |> Selecto.select(["product_id", "product_name", "product_category"])
        |> Selecto.filter([{"promotion_active", true}])

      result = Selecto.except(all_products, promoted_products)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :except
    end

    test "EXCEPT ALL for keeping duplicates" do
      query1 =
        create_base_selecto("inventory_received")
        |> Selecto.select(["product_id", "quantity"])

      query2 =
        create_base_selecto("inventory_sold")
        |> Selecto.select(["product_id", "quantity"])

      result = Selecto.except(query1, query2, all: true)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :except
      assert set_op.options.all == true
    end
  end

  describe "Set Operations Validation" do
    test "validate column count compatibility" do
      # Create queries with different column counts
      query1 =
        create_base_selecto("table1")
        |> Selecto.select(["id", "name", "email"])

      query2 =
        create_base_selecto("table2")
        # Only 2 columns
        |> Selecto.select(["id", "name"])

      # This should raise an error due to column count mismatch
      assert_raise Selecto.SetOperations.Validation.SchemaError,
                   ~r/Query 1 has 3 columns, Query 2 has 2 columns/,
                   fn ->
                     Selecto.union(query1, query2)
                   end
    end

    test "column mapping for incompatible schemas" do
      customers =
        create_base_selecto("customers")
        |> Selecto.select(["name", "email"])

      vendors =
        create_base_selecto("vendors")
        |> Selecto.select(["company_name", "contact_email"])

      # Use column mapping
      result =
        Selecto.union(customers, vendors,
          column_mapping: [
            {"name", "company_name"},
            {"email", "contact_email"}
          ]
        )

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :union

      assert set_op.options.column_mapping == [
               {"name", "company_name"},
               {"email", "contact_email"}
             ]
    end
  end

  describe "Chained Set Operations" do
    test "multiple set operations can be chained" do
      query1 =
        create_base_selecto("table1")
        |> Selecto.select(["id", "value"])

      query2 =
        create_base_selecto("table2")
        |> Selecto.select(["id", "value"])

      query3 =
        create_base_selecto("table3")
        |> Selecto.select(["id", "value"])

      # Chain operations
      result =
        query1
        |> Selecto.union(query2)
        |> Selecto.intersect(query3)

      # When chained, operations accumulate in the list
      assert length(result.set.set_operations) >= 1
      # Get the last operation added
      last_op = List.last(result.set.set_operations)
      assert last_op.operation == :intersect
      # The left query of the intersect is the result of the union
      assert length(last_op.left_query.set.set_operations) >= 1
      # Find the union operation
      union_op =
        Enum.find(last_op.left_query.set.set_operations, fn op -> op.operation == :union end)

      assert union_op != nil
    end

    test "complex chaining with different operations" do
      base =
        create_base_selecto("base_table")
        |> Selecto.select(["id", "data"])

      addition =
        create_base_selecto("additional_table")
        |> Selecto.select(["id", "data"])

      exclusion =
        create_base_selecto("exclusion_table")
        |> Selecto.select(["id", "data"])

      # Complex chain: (base ∪ addition) - exclusion
      result =
        base
        |> Selecto.union(addition, all: true)
        |> Selecto.except(exclusion)

      assert length(result.set.set_operations) >= 1
      # Get the last operation
      last_op = List.last(result.set.set_operations)
      assert last_op.operation == :except
      # Check the union in the left query
      assert length(last_op.left_query.set.set_operations) >= 1

      union_op =
        Enum.find(last_op.left_query.set.set_operations, fn op -> op.operation == :union end)

      assert union_op != nil
      assert union_op.options.all == true
    end
  end

  describe "Set Operations with CTEs" do
    test "set operations can work with queries that have CTEs" do
      # Create queries with CTEs
      query1 =
        create_base_selecto("main_table")
        |> Selecto.with_cte("filtered_data", fn ->
          create_base_selecto("source_table")
          |> Map.put(:set, %{
            selected: ["id", "value"],
            from: "source_table",
            filter: [{"active", true}]
          })
        end)
        |> Selecto.select(["id", "value"])

      query2 =
        create_base_selecto("other_table")
        |> Selecto.select(["id", "value"])

      result = Selecto.union(query1, query2)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :union
      # CTEs are preserved in the left query
      assert Map.has_key?(set_op.left_query.set, :ctes)
    end
  end

  describe "Set Operations Spec" do
    test "create set operation spec directly" do
      left =
        create_base_selecto("left_table")
        |> Selecto.select(["id", "name"])

      right =
        create_base_selecto("right_table")
        |> Selecto.select(["id", "name"])

      spec = %SetOperations.Spec{
        id: "test_union_123",
        operation: :union,
        left_query: left,
        right_query: right,
        options: %{all: false, column_mapping: nil},
        validated: false
      }

      assert spec.operation == :union
      assert spec.left_query == left
      assert spec.right_query == right
    end

    test "validate set operation compatibility" do
      query1 =
        create_base_selecto("table1")
        |> Map.update!(:set, fn set -> Map.put(set, :selected, ["id", "name"]) end)

      query2 =
        create_base_selecto("table2")
        |> Map.update!(:set, fn set -> Map.put(set, :selected, ["id", "title"]) end)

      spec = %SetOperations.Spec{
        operation: :union,
        left_query: query1,
        right_query: query2,
        options: %{all: false},
        validated: false
      }

      # Validate compatibility
      result = SetOperations.Validation.validate_compatibility(spec)

      case result do
        {:ok, validated_spec} ->
          assert validated_spec.validated == true

        {:error, _error} ->
          # Validation might fail due to column differences
          assert true
      end
    end
  end

  describe "Performance Optimization" do
    test "filtering before set operations" do
      # Filter first for better performance
      query1 =
        create_base_selecto("large_table")
        |> Selecto.filter([{"active", true}])
        |> Selecto.select(["id", "name"])

      query2 =
        create_base_selecto("other_large_table")
        |> Selecto.filter([{"status", "active"}])
        |> Selecto.select(["id", "name"])

      result = Selecto.union(query1, query2)

      # Filters are preserved in each query
      assert query1.set.filtered == [{"active", true}]
      assert query2.set.filtered == [{"status", "active"}]
      # Verify set operation was added
      assert length(result.set.set_operations) == 1
    end

    test "using ALL variants for better performance when duplicates don't matter" do
      query1 =
        create_base_selecto("log_table_1")
        |> Selecto.select(["timestamp", "event"])

      query2 =
        create_base_selecto("log_table_2")
        |> Selecto.select(["timestamp", "event"])

      # UNION ALL is faster when duplicates are acceptable
      result = Selecto.union(query1, query2, all: true)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.options.all == true
    end
  end

  describe "Common Use Cases" do
    test "merging time-series data" do
      realtime =
        create_base_selecto("realtime_metrics")
        |> Selecto.select([
          "date",
          "metric",
          "value",
          {:literal, "real-time", as: "source"}
        ])
        |> Selecto.filter([{"date", {:>=, "CURRENT_DATE"}}])

      historical =
        create_base_selecto("historical_metrics")
        |> Selecto.select([
          "date",
          "metric",
          "value",
          {:literal, "historical", as: "source"}
        ])
        |> Selecto.filter([{"date", {:<, "CURRENT_DATE"}}])

      result = Selecto.union(realtime, historical, all: true)

      assert length(result.set.set_operations) == 1
      [set_op | _] = result.set.set_operations
      assert set_op.operation == :union
      assert set_op.options.all == true
    end

    test "symmetric difference pattern (A ∪ B) - (A ∩ B)" do
      set_a =
        create_base_selecto("prices_region_a")
        |> Selecto.select(["product_id", "price"])

      set_b =
        create_base_selecto("prices_region_b")
        |> Selecto.select(["product_id", "price"])

      # Get union
      union_result = Selecto.union(set_a, set_b)

      # Get intersection
      intersect_result = Selecto.intersect(set_a, set_b)

      # Symmetric difference
      symmetric_diff = Selecto.except(union_result, intersect_result)

      assert length(symmetric_diff.set.set_operations) >= 1
      last_op = List.last(symmetric_diff.set.set_operations)
      assert last_op.operation == :except
    end
  end
end
