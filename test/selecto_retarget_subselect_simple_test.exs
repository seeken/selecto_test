defmodule SelectoRetargetSubselectSimpleTest do
  use SelectoTest.SelectoCase, async: true

  alias SelectoTest.PagilaData

  setup_all do
    PagilaData.ensure_loaded!()
  end

  # Simple test domain without complex dependencies
  def simple_domain do
    %{
      source: %{
        source_table: "users",
        primary_key: :user_id,
        fields: [:user_id, :name, :email],
        redact_fields: [],
        columns: %{
          user_id: %{type: :integer},
          name: %{type: :string},
          email: %{type: :string}
        },
        associations: %{
          posts: %{
            queryable: :posts,
            field: :posts,
            owner_key: :user_id,
            related_key: :user_id
          }
        }
      },
      schemas: %{
        posts: %{
          source_table: "posts",
          primary_key: :post_id,
          fields: [:post_id, :user_id, :title, :content],
          redact_fields: [],
          columns: %{
            post_id: %{type: :integer},
            user_id: %{type: :integer},
            title: %{type: :string},
            content: %{type: :string}
          },
          associations: %{
            users: %{
              queryable: :users,
              field: :users,
              owner_key: :user_id,
              related_key: :user_id
            }
          }
        },
        users: %{
          source_table: "users",
          primary_key: :user_id,
          fields: [:user_id, :name, :email],
          redact_fields: [],
          columns: %{
            user_id: %{type: :integer},
            name: %{type: :string},
            email: %{type: :string}
          },
          associations: %{}
        }
      },
      name: "User",
      joins: %{
        posts: %{type: :left, name: "posts"}
      }
    }
  end

  def create_test_selecto do
    SelectoTest.QueryFixture.configure(simple_domain())
  end

  # The same one-hop shape on Pagila tables, so retarget tests read real rows:
  # customers and their payments, with each payment's customer as a
  # back-reference.
  def pagila_domain do
    customer = %{
      source_table: "customer",
      primary_key: :customer_id,
      fields: [:customer_id, :first_name, :last_name, :email],
      redact_fields: [],
      columns: %{
        customer_id: %{type: :integer},
        first_name: %{type: :string},
        last_name: %{type: :string},
        email: %{type: :string}
      }
    }

    %{
      source:
        Map.put(customer, :associations, %{
          payments: %{
            queryable: :payments,
            field: :payments,
            owner_key: :customer_id,
            related_key: :customer_id
          }
        }),
      schemas: %{
        payments: %{
          source_table: "payment",
          primary_key: :payment_id,
          fields: [:payment_id, :customer_id, :amount],
          redact_fields: [],
          columns: %{
            payment_id: %{type: :integer},
            customer_id: %{type: :integer},
            amount: %{type: :decimal}
          },
          associations: %{
            customer: %{
              queryable: :customers,
              field: :customer,
              owner_key: :customer_id,
              related_key: :customer_id
            }
          }
        },
        customers: Map.put(customer, :associations, %{})
      },
      name: "Customer",
      joins: %{
        payments: %{type: :left, name: "payments"}
      }
    }
  end

  def create_pagila_selecto do
    Selecto.configure(pagila_domain(), SelectoTest.Repo)
  end

  defp rows!(query) do
    case Selecto.execute(query) do
      {:ok, {rows, _columns, _aliases}} -> rows
      {:error, error} -> flunk("query failed: #{inspect(error)}")
    end
  end

  describe "Retarget feature" do
    test "basic retarget returns the filtered customer's payments" do
      query =
        create_pagila_selecto()
        |> Selecto.filter([{"first_name", "MARY"}, {"last_name", "SMITH"}])
        |> Selecto.retarget(:payments)
        |> Selecto.select(["payment_id", "amount"])
        |> Selecto.order_by(["payment_id"])

      expected =
        PagilaData.rows!("""
        select p.payment_id, p.amount
        from payment p
        join customer c on c.customer_id = p.customer_id
        where c.first_name = 'MARY' and c.last_name = 'SMITH'
        order by p.payment_id
        """)

      assert expected != []
      assert rows!(query) == expected

      {sql, params} = Selecto.to_sql(query)
      assert sql =~ ~r/from payment selecto_root/i
      assert sql =~ ~r/in \(\s*select payments\.payment_id\s+from customer/i
      assert params == ["MARY", "SMITH"]
    end

    test "different retarget strategies return the same payments" do
      payments = fn opts ->
        create_pagila_selecto()
        |> Selecto.filter([{"first_name", "PATRICIA"}, {"last_name", "JOHNSON"}])
        |> Selecto.retarget(:payments, opts)
        |> Selecto.select(["payment_id"])
        |> Selecto.order_by(["payment_id"])
      end

      {in_sql, _} = Selecto.to_sql(payments.(strategy: :in))
      {exists_sql, _} = Selecto.to_sql(payments.(strategy: :exists))
      assert in_sql =~ ~r/selecto_root\.payment_id in \(/i
      assert exists_sql =~ ~r/\bexists\s*\(/i

      expected =
        PagilaData.rows!("""
        select p.payment_id
        from payment p
        join customer c on c.customer_id = p.customer_id
        where c.first_name = 'PATRICIA' and c.last_name = 'JOHNSON'
        order by p.payment_id
        """)

      assert expected != []
      assert rows!(payments.(strategy: :in)) == expected
      assert rows!(payments.(strategy: :exists)) == expected
    end
  end

  describe "Subselect feature SQL generation" do
    test "basic subselect generates correct SQL structure" do
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.subselect(["posts.title"])

      {sql, _params} = Selecto.to_sql(selecto)

      # Should have main SELECT fields
      assert sql =~ "name"
      assert sql =~ "email"

      # Should contain subselect with JSON aggregation
      assert sql =~ "json_agg"
      # Subquery SELECT
      assert sql =~ ~r/select/i

      # Should contain correlation condition
      assert sql =~ ~r/where/i
      # Correlation join
      assert sql =~ "="
    end

    test "different aggregation formats produce different SQL" do
      base_selecto =
        create_test_selecto()
        |> Selecto.select(["name"])

      # JSON aggregation
      json_selecto =
        base_selecto
        |> Selecto.subselect([
          %{fields: ["title"], target_schema: :posts, format: :json_agg, alias: "json_posts"}
        ])

      {json_sql, _} = Selecto.to_sql(json_selecto)

      # Array aggregation
      array_selecto =
        base_selecto
        |> Selecto.subselect([
          %{fields: ["title"], target_schema: :posts, format: :array_agg, alias: "array_posts"}
        ])

      {array_sql, _} = Selecto.to_sql(array_selecto)

      # Should have different aggregation functions
      assert json_sql =~ ~r/json_agg/i
      assert array_sql =~ ~r/array_agg/i
    end

    test "multiple subselects work together" do
      selecto =
        create_test_selecto()
        |> Selecto.select(["name"])
        |> Selecto.subselect([
          %{
            fields: ["title"],
            target_schema: :posts,
            format: :json_agg,
            alias: "post_titles"
          },
          %{
            fields: ["content"],
            target_schema: :posts,
            format: :count,
            alias: "post_count"
          }
        ])

      {sql, _params} = Selecto.to_sql(selecto)

      # Should have both subselects
      assert sql =~ "json_agg"
      assert sql =~ "count"
      assert sql =~ "AS \"post_titles\""
      assert sql =~ "AS \"post_count\""
    end
  end

  describe "Combined Retarget and Subselect features" do
    test "retarget with a back-reference subselect returns each payment's customer" do
      rows =
        create_pagila_selecto()
        |> Selecto.filter({"customer_id", {:lt, 4}})
        |> Selecto.retarget(:payments)
        |> Selecto.filter({"amount", {:gt, 7}})
        |> Selecto.select(["payment_id", "amount"])
        |> Selecto.subselect([
          %{
            fields: ["first_name", "last_name"],
            # Back-reference to the payment's customer
            target_schema: :customers,
            format: :json_agg,
            alias: "customer"
          }
        ])
        |> Selecto.order_by(["payment_id"])
        |> rows!()

      expected =
        PagilaData.rows!("""
        select p.payment_id, p.amount, c.first_name, c.last_name
        from payment p
        join customer c on c.customer_id = p.customer_id
        where p.customer_id < 4 and p.amount > 7
        order by p.payment_id
        """)

      assert expected != []

      assert rows ==
               Enum.map(expected, fn [payment_id, amount, first_name, last_name] ->
                 [payment_id, amount, [%{"first_name" => first_name, "last_name" => last_name}]]
               end)
    end
  end

  describe "Feature validation" do
    test "retarget validates the target is a join of the domain" do
      error =
        assert_raise Selecto.Retarget.Error, ~r/unknown join invalid_schema/, fn ->
          create_test_selecto()
          |> Selecto.retarget(:invalid_schema)
        end

      assert error.code == :unknown_association
    end

    test "subselect validates target schema exists" do
      assert_raise ArgumentError, ~r/Target schema.*not found/, fn ->
        create_test_selecto()
        |> Selecto.subselect(["invalid_schema.field"])
      end
    end

    test "subselect validates fields exist" do
      assert_raise ArgumentError, ~r/Fields.*not found in schema/, fn ->
        create_test_selecto()
        |> Selecto.subselect(["posts.invalid_field"])
      end
    end
  end

  describe "API functionality" do
    test "retarget API functions work correctly" do
      selecto = create_pagila_selecto() |> Selecto.filter({"customer_id", 1})

      # Initially no retarget
      refute Selecto.Retarget.has_retarget?(selecto)
      assert Selecto.Retarget.get_retarget_config(selecto) == nil

      # Add retarget
      retargeted = Selecto.retarget(selecto, :payments)
      assert Selecto.Retarget.has_retarget?(retargeted)

      config = Selecto.Retarget.get_retarget_config(retargeted)
      assert config.path == "payments"
      assert config.join == :payments
      assert config.target_schema == :payments
      assert config.primary_key == :payment_id
      assert config.strategy == :in
      assert config.origin == selecto

      # Reset retarget returns the customer query
      reset = Selecto.Retarget.reset_retarget(retargeted)
      refute Selecto.Retarget.has_retarget?(reset)

      assert rows!(Selecto.select(reset, ["first_name", "last_name"])) ==
               PagilaData.rows!(
                 "select first_name, last_name from customer where customer_id = 1"
               )
    end

    test "subselect API functions work correctly" do
      selecto = create_test_selecto()

      # Initially no subselects
      refute Selecto.Subselect.has_subselects?(selecto)
      assert Selecto.Subselect.get_subselect_configs(selecto) == []

      # Add subselects
      subselected = Selecto.subselect(selecto, ["posts.title"])
      assert Selecto.Subselect.has_subselects?(subselected)

      configs = Selecto.Subselect.get_subselect_configs(subselected)
      assert length(configs) == 1

      [config] = configs
      assert config.target_schema == :posts
      assert config.fields == ["title"]

      # Clear subselects
      cleared = Selecto.Subselect.clear_subselects(subselected)
      refute Selecto.Subselect.has_subselects?(cleared)
    end
  end
end
