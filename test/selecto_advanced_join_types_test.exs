defmodule SelectoAdvancedJoinTypesTest do
  use ExUnit.Case, async: true

  # Core keeps the adjacency-list hierarchy (PostgreSQL) and the star
  # dimension families. materialized_path and closure_table hierarchies and
  # snowflake normalization_joins lists were removed: they refuse at
  # configure and name what replaces them.

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

      assert sql =~ ~r/WITH RECURSIVE (__selecto_hierarchy_manager_tree_[0-9a-f]{10}) AS/
      [cte] = Regex.run(~r/__selecto_hierarchy_manager_tree_[0-9a-f]{10}/, sql)

      assert sql =~ ~s(FROM employee c WHERE c."manager_id" IS NULL)
      assert sql =~ ~s(JOIN #{cte} h ON c."manager_id" = h."employee_id")

      assert sql =~
               ~r/left join #{cte} manager_tree on manager_tree\.employee_id = selecto_root\.manager_id/i

      assert sql =~ "manager_tree.level"
      assert sql =~ "manager_tree.path"
      assert params in [[], [4]]

      if params == [] do
        assert sql =~ "h.level < 4"
      else
        assert sql =~ "h.level < $1"
      end
    end

    test "materialized path hierarchies were removed and refuse at configure" do
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

      assert_raise Selecto.DomainValidator.ValidationError,
                   ~r/materialized_path hierarchies were removed.*recursive query member/,
                   fn -> Selecto.configure(domain, SelectoTest.Repo) end
    end

    test "closure table hierarchies were removed and refuse at configure" do
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

      assert_raise Selecto.DomainValidator.ValidationError,
                   ~r/closure_table hierarchies were removed.*recursive query member/,
                   fn -> Selecto.configure(domain, SelectoTest.Repo) end
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

      assert sql =~ ~r/left join customers customer on customer\.id = selecto_root\.customer_id/i
      assert params == []
    end

    test "snowflake_dimension without normalization is a star dimension" do
      star =
        order_domain(%{
          name: "Customer",
          type: :star_dimension,
          display_field: :name,
          fields: %{name: %{type: :string}}
        })

      snowflake =
        order_domain(%{
          name: "Customer",
          type: :snowflake_dimension,
          display_field: :name,
          fields: %{name: %{type: :string}}
        })

      to_sql = fn domain ->
        domain
        |> Selecto.configure(SelectoTest.Repo)
        |> Selecto.select(["order_id", "customer.name", "total"])
        |> Selecto.limit(5)
        |> Selecto.to_sql()
      end

      assert to_sql.(snowflake) == to_sql.(star)
    end
  end

  describe "advanced join validation" do
    test "snowflake normalization_joins lists were removed and refuse at configure" do
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

      assert_raise Selecto.DomainValidator.ValidationError,
                   ~r/normalization_joins were removed.*nested joins/,
                   fn -> Selecto.configure(domain, SelectoTest.Repo) end
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
