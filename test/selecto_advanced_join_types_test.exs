defmodule SelectoAdvancedJoinTypesTest do
  use ExUnit.Case, async: true

  describe "hierarchical joins" do
    test "adjacency list hierarchy query uses configured id/parent/name fields" do
      domain =
        hierarchy_domain(%{
          name: "Manager Tree",
          type: :hierarchical,
          hierarchy_type: :adjacency_list,
          depth_limit: 4,
          id_field: :employee_id,
          parent_field: :manager_id,
          name_field: :full_name,
          fields: %{full_name: %{type: :string}}
        })

      {sql, params} =
        domain
        |> Selecto.configure(SelectoTest.Repo)
        |> Selecto.select([
          "full_name",
          "manager_tree.full_name",
          "manager_tree_level",
          "manager_tree_path"
        ])
        |> Selecto.limit(10)
        |> Selecto.to_sql()

      assert sql =~ "WITH RECURSIVE manager_tree_hierarchy AS"
      assert sql =~ "SELECT employee_id, full_name, manager_id"
      assert sql =~ "FROM employee WHERE manager_id IS NULL"
      assert sql =~ "JOIN manager_tree_hierarchy h ON c.manager_id = h.employee_id"
      assert sql =~ "LEFT JOIN manager_tree_hierarchy manager_tree"
      assert sql =~ "manager_tree.level"
      assert sql =~ "manager_tree.path"
      assert params == [4]
    end

    test "materialized path hierarchy query emits path CTE and depth/path-array helpers" do
      domain =
        hierarchy_domain(%{
          name: "Manager Tree",
          type: :hierarchical,
          hierarchy_type: :materialized_path,
          path_field: :manager_path,
          path_separator: "/",
          root_path: "ceo",
          fields: %{full_name: %{type: :string}}
        })

      {sql, params} =
        domain
        |> Selecto.configure(SelectoTest.Repo)
        |> Selecto.select([
          "full_name",
          "manager_tree.full_name",
          "manager_tree_depth",
          "manager_tree_path_array"
        ])
        |> Selecto.limit(5)
        |> Selecto.to_sql()

      assert sql =~ "WITH manager_tree_materialized_path AS"
      assert sql =~ "string_to_array(manager_path, '/') as path_array"
      assert sql =~ "LEFT JOIN manager_tree_materialized_path manager_tree"
      assert sql =~ "manager_tree.depth"
      assert sql =~ "manager_tree.path_array"
      assert params == ["ceo/%"]
    end

    test "closure table hierarchy query emits closure CTE and helper columns" do
      domain =
        hierarchy_domain(%{
          name: "Manager Tree",
          type: :hierarchical,
          hierarchy_type: :closure_table,
          closure_table: "employee_closure",
          ancestor_field: :ancestor_id,
          descendant_field: :descendant_id,
          depth_field: :depth,
          fields: %{full_name: %{type: :string}}
        })

      {sql, params} =
        domain
        |> Selecto.configure(SelectoTest.Repo)
        |> Selecto.select([
          "full_name",
          "manager_tree.full_name",
          "manager_tree_depth",
          "manager_tree_descendant_count"
        ])
        |> Selecto.limit(5)
        |> Selecto.to_sql()

      assert sql =~ "WITH manager_tree_closure AS"
      assert sql =~ "JOIN employee_closure cl ON c.id = cl.descendant_id"
      assert sql =~ "COUNT(*) FROM employee_closure cl2"
      assert sql =~ "LEFT JOIN manager_tree_closure manager_tree"
      assert sql =~ "manager_tree.depth"
      assert sql =~ "manager_tree.descendant_count"
      assert params == []
    end
  end

  describe "OLAP join types" do
    test "star_dimension joins through selecto_root alias" do
      domain =
        order_domain(%{
          name: "Customer",
          type: :star_dimension,
          display_field: :name,
          fields: %{name: %{type: :string}}
        })

      {sql, params} =
        domain
        |> Selecto.configure(SelectoTest.Repo)
        |> Selecto.select(["order_id", "customer.name", "total"])
        |> Selecto.limit(5)
        |> Selecto.to_sql()

      assert sql =~ "LEFT JOIN customers customer ON selecto_root.customer_id = customer.id"
      assert params == []
    end

    test "snowflake_dimension adds normalization chain joins" do
      domain =
        order_domain(%{
          name: "Customer",
          type: :snowflake_dimension,
          display_field: :name,
          normalization_joins: [
            %{table: "regions", key: "id", foreign_key: "region_id"}
          ],
          fields: %{name: %{type: :string}}
        })

      {sql, params} =
        domain
        |> Selecto.configure(SelectoTest.Repo)
        |> Selecto.select(["order_id", "customer.name", "total"])
        |> Selecto.limit(5)
        |> Selecto.to_sql()

      assert sql =~ "LEFT JOIN customers customer ON selecto_root.customer_id = customer.id"

      assert sql =~
               "LEFT JOIN regions customer_regions ON customer.region_id = customer_regions.id"

      assert params == []
    end
  end

  describe "advanced join validation" do
    test "snowflake_dimension requires normalization_joins" do
      domain =
        order_domain(%{
          name: "Customer",
          type: :snowflake_dimension,
          display_field: :name,
          fields: %{name: %{type: :string}}
        })

      assert_raise Selecto.DomainValidator.ValidationError, ~r/normalization_joins/, fn ->
        Selecto.configure(domain, SelectoTest.Repo)
      end
    end

    test "materialized_path hierarchy requires path_field" do
      domain =
        hierarchy_domain(%{
          name: "Manager Tree",
          type: :hierarchical,
          hierarchy_type: :materialized_path,
          fields: %{full_name: %{type: :string}}
        })

      assert_raise Selecto.DomainValidator.ValidationError, ~r/path_field/, fn ->
        Selecto.configure(domain, SelectoTest.Repo)
      end
    end
  end

  defp hierarchy_domain(join_config) do
    %{
      name: "Employees",
      source: %{
        source_table: "employee",
        primary_key: :employee_id,
        fields: [:employee_id, :full_name, :manager_id, :manager_path],
        redact_fields: [],
        columns: %{
          employee_id: %{type: :integer},
          full_name: %{type: :string},
          manager_id: %{type: :integer},
          manager_path: %{type: :string}
        },
        associations: %{
          manager_tree: %{
            field: :manager_tree,
            queryable: :employees,
            owner_key: :manager_id,
            related_key: :employee_id
          }
        }
      },
      schemas: %{
        employees: %{
          source_table: "employee",
          primary_key: :employee_id,
          fields: [:employee_id, :full_name, :manager_id, :manager_path],
          redact_fields: [],
          columns: %{
            employee_id: %{type: :integer},
            full_name: %{type: :string},
            manager_id: %{type: :integer},
            manager_path: %{type: :string}
          },
          associations: %{}
        }
      },
      joins: %{manager_tree: join_config}
    }
  end

  defp order_domain(join_config) do
    %{
      name: "Orders",
      source: %{
        source_table: "orders",
        primary_key: :order_id,
        fields: [:order_id, :customer_id, :total],
        redact_fields: [],
        columns: %{
          order_id: %{type: :integer},
          customer_id: %{type: :integer},
          total: %{type: :decimal}
        },
        associations: %{
          customer: %{
            field: :customer,
            queryable: :customers,
            owner_key: :customer_id,
            related_key: :id
          }
        }
      },
      schemas: %{
        customers: %{
          source_table: "customers",
          primary_key: :id,
          fields: [:id, :name, :region_id],
          redact_fields: [],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string},
            region_id: %{type: :integer}
          },
          associations: %{}
        },
        regions: %{
          source_table: "regions",
          primary_key: :id,
          fields: [:id, :name],
          redact_fields: [],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{}
        }
      },
      joins: %{customer: join_config}
    }
  end
end
