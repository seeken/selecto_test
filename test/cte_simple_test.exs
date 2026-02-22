defmodule CteSimpleTest do
  use ExUnit.Case, async: true

  describe "Basic CTE Operations" do
    test "simple CTE generates correct SQL" do
      # Create a CTE specification
      cte_spec =
        Selecto.Advanced.CTE.create_cte(
          "active_customers",
          fn ->
            # Create a minimal selecto query
            %{
              set: %{
                selected: ["customer_id", "name"],
                filtered: [{"active", true}],
                group_by: [],
                order_by: []
              },
              domain: %{},
              source: %{
                fields: [:customer_id, :name, :active],
                redact_fields: [],
                columns: %{
                  customer_id: %{type: :integer},
                  name: %{type: :string},
                  active: %{type: :boolean}
                }
              },
              config: %{
                source_table: "customers",
                source: %{
                  fields: [:customer_id, :name, :active],
                  redact_fields: [],
                  columns: %{
                    customer_id: %{type: :integer},
                    name: %{type: :string},
                    active: %{type: :boolean}
                  }
                },
                joins: %{},
                columns: %{
                  "customer_id" => %{
                    name: "customer_id",
                    field: "customer_id",
                    requires_join: nil
                  },
                  "name" => %{name: "name", field: "name", requires_join: nil},
                  "active" => %{name: "active", field: "active", requires_join: nil}
                }
              }
            }
          end
        )

      # Build CTE definition
      {cte_iodata, _params} = Selecto.Builder.CteSql.build_cte_definition(cte_spec)

      # Finalize to get SQL string
      {sql_string, _final_params} = Selecto.SQL.Params.finalize(cte_iodata)

      # Verify SQL structure
      assert sql_string =~ "active_customers AS"
      assert sql_string =~ "select"

      # The query builder function would need actual implementation
      # For now we're just testing the CTE builder structure
    end

    test "CTE with explicit columns" do
      # Create a CTE specification with columns
      cte_spec =
        Selecto.Advanced.CTE.create_cte(
          "customer_stats",
          fn ->
            # Create a minimal selecto query
            %{
              set: %{
                selected: ["customer_id", {:literal, "COUNT(*) AS order_count"}],
                group_by: ["customer_id"],
                filtered: [],
                order_by: []
              },
              domain: %{},
              source: %{
                fields: [:customer_id],
                redact_fields: [],
                columns: %{
                  customer_id: %{type: :integer}
                }
              },
              config: %{
                source_table: "customers",
                source: %{
                  fields: [:customer_id],
                  redact_fields: [],
                  columns: %{
                    customer_id: %{type: :integer}
                  }
                },
                joins: %{},
                columns: %{
                  "customer_id" => %{
                    name: "customer_id",
                    field: "customer_id",
                    requires_join: nil
                  }
                }
              }
            }
          end,
          columns: ["customer_id", "order_count"]
        )

      # Verify the spec has columns
      assert cte_spec.columns == ["customer_id", "order_count"]
      assert cte_spec.type == :normal
      assert cte_spec.validated == true
    end

    test "multiple CTEs with WITH clause" do
      # Create multiple CTE specifications
      cte1 =
        Selecto.Advanced.CTE.create_cte(
          "filtered_customers",
          fn ->
            %{
              set: %{
                selected: ["customer_id", "name"],
                filtered: [{"status", "active"}],
                group_by: [],
                order_by: []
              },
              domain: %{},
              source: %{
                fields: [:customer_id, :name, :status],
                redact_fields: [],
                columns: %{
                  customer_id: %{type: :integer},
                  name: %{type: :string},
                  status: %{type: :string}
                }
              },
              config: %{
                source_table: "customers",
                source: %{
                  fields: [:customer_id, :name, :status],
                  redact_fields: [],
                  columns: %{
                    customer_id: %{type: :integer},
                    name: %{type: :string},
                    status: %{type: :string}
                  }
                },
                joins: %{},
                columns: %{
                  "customer_id" => %{
                    name: "customer_id",
                    field: "customer_id",
                    requires_join: nil
                  },
                  "name" => %{name: "name", field: "name", requires_join: nil},
                  "status" => %{name: "status", field: "status", requires_join: nil}
                }
              }
            }
          end
        )

      cte2 =
        Selecto.Advanced.CTE.create_cte(
          "customer_orders",
          fn ->
            %{
              set: %{
                selected: ["customer_id", {:literal, "COUNT(*) AS total_orders"}],
                group_by: ["customer_id"],
                filtered: [],
                order_by: []
              },
              domain: %{},
              source: %{
                fields: [:customer_id],
                redact_fields: [],
                columns: %{
                  customer_id: %{type: :integer}
                }
              },
              config: %{
                source_table: "customers",
                source: %{
                  fields: [:customer_id],
                  redact_fields: [],
                  columns: %{
                    customer_id: %{type: :integer}
                  }
                },
                joins: %{},
                columns: %{
                  "customer_id" => %{
                    name: "customer_id",
                    field: "customer_id",
                    requires_join: nil
                  }
                }
              }
            }
          end
        )

      # Build WITH clause for multiple CTEs
      {with_clause_iodata, _params} = Selecto.Builder.CteSql.build_with_clause([cte1, cte2])

      # Finalize to get SQL string
      {sql_string, _final_params} = Selecto.SQL.Params.finalize(with_clause_iodata)

      # Verify SQL structure
      assert sql_string =~ "WITH"
      assert sql_string =~ "filtered_customers AS"
      assert sql_string =~ "customer_orders AS"
    end
  end

  describe "Recursive CTE Operations" do
    test "recursive CTE specification" do
      # Create a recursive CTE specification
      cte_spec =
        Selecto.Advanced.CTE.create_recursive_cte(
          "org_hierarchy",
          base_query: fn ->
            %{
              set: %{
                selected: ["employee_id", "name", "manager_id", {:literal, "0 AS level"}],
                filtered: [{"manager_id", nil}],
                group_by: [],
                order_by: []
              },
              domain: %{},
              source: %{
                fields: [:employee_id, :name, :manager_id],
                redact_fields: [],
                columns: %{
                  employee_id: %{type: :integer},
                  name: %{type: :string},
                  manager_id: %{type: :integer}
                }
              },
              config: %{
                source_table: "employees",
                source: %{
                  fields: [:employee_id, :name, :manager_id],
                  redact_fields: [],
                  columns: %{
                    employee_id: %{type: :integer},
                    name: %{type: :string},
                    manager_id: %{type: :integer}
                  }
                },
                joins: %{},
                columns: %{
                  "employee_id" => %{
                    name: "employee_id",
                    field: "employee_id",
                    requires_join: nil
                  },
                  "name" => %{name: "name", field: "name", requires_join: nil},
                  "manager_id" => %{name: "manager_id", field: "manager_id", requires_join: nil}
                }
              }
            }
          end,
          recursive_query: fn cte_ref ->
            %{
              set: %{
                selected: ["e.employee_id", "e.name", "e.manager_id", {:literal, "h.level + 1"}],
                from: "employee e",
                joins: [{:inner, cte_ref, on: "e.manager_id = h.employee_id"}],
                filtered: [],
                group_by: [],
                order_by: []
              },
              domain: %{},
              source: %{
                fields: [:employee_id, :name, :manager_id],
                redact_fields: [],
                columns: %{
                  employee_id: %{type: :integer},
                  name: %{type: :string},
                  manager_id: %{type: :integer}
                }
              },
              config: %{
                source_table: "employees",
                source: %{
                  fields: [:employee_id, :name, :manager_id],
                  redact_fields: [],
                  columns: %{
                    employee_id: %{type: :integer},
                    name: %{type: :string},
                    manager_id: %{type: :integer}
                  }
                },
                joins: %{},
                columns: %{
                  "employee_id" => %{
                    name: "employee_id",
                    field: "employee_id",
                    requires_join: nil
                  },
                  "name" => %{name: "name", field: "name", requires_join: nil},
                  "manager_id" => %{name: "manager_id", field: "manager_id", requires_join: nil}
                }
              }
            }
          end
        )

      # Verify the spec
      assert cte_spec.type == :recursive
      assert cte_spec.name == "org_hierarchy"
      assert is_function(cte_spec.base_query, 0)
      assert is_function(cte_spec.recursive_query, 1)
      assert cte_spec.validated == true
    end

    test "recursive CTE with WITH RECURSIVE clause" do
      # Create a recursive CTE
      recursive_cte =
        Selecto.Advanced.CTE.create_recursive_cte(
          "number_series",
          base_query: fn ->
            %{
              set: %{
                selected: [{:literal, "1 AS n"}],
                filtered: [],
                group_by: [],
                order_by: []
              },
              domain: %{},
              source: %{
                fields: [:n],
                redact_fields: [],
                columns: %{
                  n: %{type: :integer}
                }
              },
              config: %{
                source_table: "numbers",
                source: %{
                  fields: [:n],
                  redact_fields: [],
                  columns: %{
                    n: %{type: :integer}
                  }
                },
                joins: %{},
                columns: %{
                  "n" => %{name: "n", field: "n", requires_join: nil}
                }
              }
            }
          end,
          recursive_query: fn _cte_ref ->
            %{
              set: %{
                selected: [{:literal, "n + 1"}],
                from: "number_series",
                filtered: [{"n", {:<, 10}}],
                group_by: [],
                order_by: []
              },
              domain: %{},
              source: %{
                fields: [:n],
                redact_fields: [],
                columns: %{
                  n: %{type: :integer}
                }
              },
              config: %{
                source_table: "numbers",
                source: %{
                  fields: [:n],
                  redact_fields: [],
                  columns: %{
                    n: %{type: :integer}
                  }
                },
                joins: %{},
                columns: %{
                  "n" => %{name: "n", field: "n", requires_join: nil}
                }
              }
            }
          end
        )

      # Build WITH clause
      {with_clause_iodata, _params} = Selecto.Builder.CteSql.build_with_clause([recursive_cte])

      # Finalize to get SQL string
      {sql_string, _final_params} = Selecto.SQL.Params.finalize(with_clause_iodata)

      # Verify SQL structure
      assert sql_string =~ "WITH RECURSIVE"
      assert sql_string =~ "number_series AS"
      assert sql_string =~ "UNION ALL"
    end
  end

  describe "CTE Integration with Selecto" do
    test "adding CTEs to Selecto query" do
      # Create a basic selecto instance
      selecto = %{
        set: %{
          selected: ["*"],
          from: "main_table"
        },
        domain: %{},
        config: %{}
      }

      # Add a CTE using with_cte
      selecto_with_cte =
        Selecto.with_cte(
          selecto,
          "temp_data",
          fn ->
            %{
              set: %{
                selected: ["id", "value"],
                from: "source_table",
                filtered: [{"active", true}]
              },
              domain: %{},
              config: %{}
            }
          end
        )

      # Verify CTE was added
      assert Map.has_key?(selecto_with_cte.set, :ctes)
      assert length(selecto_with_cte.set.ctes) == 1
      cte = hd(selecto_with_cte.set.ctes)
      assert cte.name == "temp_data"
    end

    test "adding multiple CTEs with with_ctes" do
      # Create a basic selecto instance
      selecto = %{
        set: %{
          selected: ["*"],
          from: "main_table"
        },
        domain: %{},
        config: %{}
      }

      # Create CTE specs
      cte1 =
        Selecto.Advanced.CTE.create_cte("cte1", fn -> %{set: %{}, domain: %{}, config: %{}} end)

      cte2 =
        Selecto.Advanced.CTE.create_cte("cte2", fn -> %{set: %{}, domain: %{}, config: %{}} end)

      # Add multiple CTEs
      selecto_with_ctes = Selecto.with_ctes(selecto, [cte1, cte2])

      # Verify CTEs were added
      assert length(selecto_with_ctes.set.ctes) == 2
      assert Enum.map(selecto_with_ctes.set.ctes, & &1.name) == ["cte1", "cte2"]
    end
  end
end
