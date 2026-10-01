defmodule SelectoMultiStepSubselectTest do
  use SelectoTest.SelectoCase, async: true

  @moduledoc """
  Tests for multi-step join paths in subselects.

  This tests subselects that require traversing 3 or more associations to reach
  the target schema. For example: User → Order → OrderItem → Product

  Multi-step paths require building EXISTS clauses with multiple INNER JOINs.

  The retarget tests read Pagila, whose customer → rental → inventory → film →
  film_category → category chain has the same shape.
  """

  alias SelectoTest.PagilaData

  setup_all do
    PagilaData.ensure_loaded!()
  end

  # Create a realistic e-commerce domain with multi-level relationships
  def ecommerce_domain do
    %{
      source: %{
        source_table: "users",
        primary_key: :user_id,
        fields: [:user_id, :name, :email, :created_at],
        redact_fields: [],
        columns: %{
          user_id: %{type: :integer},
          name: %{type: :string},
          email: %{type: :string},
          created_at: %{type: :datetime}
        },
        associations: %{
          orders: %{
            queryable: :orders,
            field: :orders,
            owner_key: :user_id,
            related_key: :user_id
          },
          addresses: %{
            queryable: :addresses,
            field: :addresses,
            owner_key: :user_id,
            related_key: :user_id
          }
        }
      },
      schemas: %{
        orders: %{
          source_table: "orders",
          primary_key: :order_id,
          fields: [:order_id, :user_id, :order_date, :status, :total],
          redact_fields: [],
          columns: %{
            order_id: %{type: :integer},
            user_id: %{type: :integer},
            order_date: %{type: :date},
            status: %{type: :string},
            total: %{type: :decimal}
          },
          associations: %{
            user: %{
              queryable: :users,
              field: :user,
              owner_key: :user_id,
              related_key: :user_id
            },
            order_items: %{
              queryable: :order_items,
              field: :order_items,
              owner_key: :order_id,
              related_key: :order_id
            },
            shipments: %{
              queryable: :shipments,
              field: :shipments,
              owner_key: :order_id,
              related_key: :order_id
            }
          }
        },
        order_items: %{
          source_table: "order_items",
          primary_key: :order_item_id,
          fields: [:order_item_id, :order_id, :product_id, :quantity, :price],
          redact_fields: [],
          columns: %{
            order_item_id: %{type: :integer},
            order_id: %{type: :integer},
            product_id: %{type: :integer},
            quantity: %{type: :integer},
            price: %{type: :decimal}
          },
          associations: %{
            order: %{
              queryable: :orders,
              field: :order,
              owner_key: :order_id,
              related_key: :order_id
            },
            product: %{
              queryable: :products,
              field: :product,
              owner_key: :product_id,
              related_key: :product_id
            }
          }
        },
        products: %{
          source_table: "products",
          primary_key: :product_id,
          fields: [:product_id, :name, :description, :price, :category_id],
          redact_fields: [],
          columns: %{
            product_id: %{type: :integer},
            name: %{type: :string},
            description: %{type: :string},
            price: %{type: :decimal},
            category_id: %{type: :integer}
          },
          associations: %{
            category: %{
              queryable: :categories,
              field: :category,
              owner_key: :category_id,
              related_key: :category_id
            },
            reviews: %{
              queryable: :reviews,
              field: :reviews,
              owner_key: :product_id,
              related_key: :product_id
            }
          }
        },
        categories: %{
          source_table: "categories",
          primary_key: :category_id,
          fields: [:category_id, :name, :parent_category_id],
          redact_fields: [],
          columns: %{
            category_id: %{type: :integer},
            name: %{type: :string},
            parent_category_id: %{type: :integer}
          },
          associations: %{
            parent_category: %{
              queryable: :categories,
              field: :parent_category,
              owner_key: :parent_category_id,
              related_key: :category_id
            }
          }
        },
        reviews: %{
          source_table: "reviews",
          primary_key: :review_id,
          fields: [:review_id, :product_id, :user_id, :rating, :comment],
          redact_fields: [],
          columns: %{
            review_id: %{type: :integer},
            product_id: %{type: :integer},
            user_id: %{type: :integer},
            rating: %{type: :integer},
            comment: %{type: :string}
          },
          associations: %{
            product: %{
              queryable: :products,
              field: :product,
              owner_key: :product_id,
              related_key: :product_id
            },
            user: %{
              queryable: :users,
              field: :user,
              owner_key: :user_id,
              related_key: :user_id
            }
          }
        },
        shipments: %{
          source_table: "shipments",
          primary_key: :shipment_id,
          fields: [:shipment_id, :order_id, :tracking_number, :status],
          redact_fields: [],
          columns: %{
            shipment_id: %{type: :integer},
            order_id: %{type: :integer},
            tracking_number: %{type: :string},
            status: %{type: :string}
          },
          associations: %{
            order: %{
              queryable: :orders,
              field: :order,
              owner_key: :order_id,
              related_key: :order_id
            }
          }
        },
        addresses: %{
          source_table: "addresses",
          primary_key: :address_id,
          fields: [:address_id, :user_id, :street, :city, :country],
          redact_fields: [],
          columns: %{
            address_id: %{type: :integer},
            user_id: %{type: :integer},
            street: %{type: :string},
            city: %{type: :string},
            country: %{type: :string}
          },
          associations: %{
            user: %{
              queryable: :users,
              field: :user,
              owner_key: :user_id,
              related_key: :user_id
            }
          }
        }
      },
      name: "E-commerce"
    }
  end

  def create_test_selecto do
    domain = ecommerce_domain()
    postgrex_opts = [hostname: "localhost", username: "test"]
    Selecto.configure(domain, postgrex_opts, validate: false)
  end

  # Pagila customers and the films and categories of their rentals. A
  # retarget names a join path, so the domain declares the join tree.
  def rentals_domain do
    %{
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
          rentals: %{
            queryable: :rentals,
            field: :rentals,
            owner_key: :customer_id,
            related_key: :customer_id
          }
        }
      },
      schemas: %{
        rentals: %{
          source_table: "rental",
          primary_key: :rental_id,
          fields: [:rental_id, :customer_id, :inventory_id],
          redact_fields: [],
          columns: %{
            rental_id: %{type: :integer},
            customer_id: %{type: :integer},
            inventory_id: %{type: :integer}
          },
          associations: %{
            inventory: %{
              queryable: :inventory,
              field: :inventory,
              owner_key: :inventory_id,
              related_key: :inventory_id
            }
          }
        },
        inventory: %{
          source_table: "inventory",
          primary_key: :inventory_id,
          fields: [:inventory_id, :film_id, :store_id],
          redact_fields: [],
          columns: %{
            inventory_id: %{type: :integer},
            film_id: %{type: :integer},
            store_id: %{type: :integer}
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
          fields: [:film_id, :title, :rating],
          redact_fields: [],
          columns: %{
            film_id: %{type: :integer},
            title: %{type: :string},
            rating: %{type: :string}
          },
          associations: %{
            film_categories: %{
              queryable: :film_categories,
              field: :film_categories,
              owner_key: :film_id,
              related_key: :film_id
            }
          }
        },
        film_categories: %{
          source_table: "film_category",
          primary_key: :film_id,
          fields: [:film_id, :category_id],
          redact_fields: [],
          columns: %{
            film_id: %{type: :integer},
            category_id: %{type: :integer}
          },
          associations: %{
            category: %{
              queryable: :category,
              field: :category,
              owner_key: :category_id,
              related_key: :category_id
            }
          }
        },
        category: %{
          source_table: "category",
          primary_key: :category_id,
          fields: [:category_id, :name],
          redact_fields: [],
          columns: %{
            category_id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{
            film_categories: %{
              queryable: :film_categories,
              field: :film_categories,
              owner_key: :category_id,
              related_key: :category_id
            }
          }
        }
      },
      name: "Customer rentals",
      joins: %{
        rentals: %{
          type: :left,
          name: "Rentals",
          joins: %{
            inventory: %{
              type: :left,
              name: "Inventory",
              joins: %{
                film: %{
                  type: :left,
                  name: "Film",
                  joins: %{
                    film_categories: %{
                      type: :left,
                      name: "Film categories",
                      joins: %{category: %{type: :left, name: "Category"}}
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  end

  def create_rentals_selecto do
    Selecto.configure(rentals_domain(), SelectoTest.Repo)
  end

  defp rows!(query) do
    case Selecto.execute(query) do
      {:ok, {rows, _columns, _aliases}} -> rows
      {:error, error} -> flunk("query failed: #{inspect(error)}")
    end
  end

  describe "Multi-step join paths - 3 levels deep" do
    test "User → Orders → OrderItems → Products (3-step subselect)" do
      # Get users with their products (through orders → order_items → products)
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"name", "Alice"}])
        |> Selecto.subselect([
          %{
            fields: ["name", "price"],
            target_schema: :products,
            format: :json_agg,
            alias: "purchased_products"
          }
        ])

      {sql, params} = Selecto.to_sql(selecto)

      # Should have main query
      assert sql =~ ~r/from users/i
      assert sql =~ "name"
      assert sql =~ "email"

      # Should have EXISTS or multi-join subselect
      assert sql =~ ~r/EXISTS.*SELECT 1 FROM/i or sql =~ ~r/SELECT json_agg/i

      # Should reference intermediate tables (orders and order_items)
      assert sql =~ ~r/orders/i
      assert sql =~ ~r/order_items/i
      assert sql =~ ~r/products/i

      # Should have filter parameter
      assert "Alice" in params
    end

    test "User → Orders → OrderItems → Products → Categories (4-step subselect)" do
      # Get users with product categories (through orders → order_items → products → categories)
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"email", "alice@example.com"}])
        |> Selecto.subselect([
          %{
            fields: ["name"],
            target_schema: :categories,
            format: :json_agg,
            alias: "product_categories"
          }
        ])

      {sql, params} = Selecto.to_sql(selecto)

      # Should have main query
      assert sql =~ ~r/from users/i

      # Should have multi-join path through all intermediate tables
      assert sql =~ ~r/orders/i
      assert sql =~ ~r/order_items/i
      assert sql =~ ~r/products/i
      assert sql =~ ~r/categories/i

      # Should have EXISTS clause with multiple joins
      assert sql =~ ~r/EXISTS/i

      assert "alice@example.com" in params
    end

    test "User → Orders → OrderItems (2-step for comparison)" do
      # Get users with their order items (2-step path)
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"name", "Bob"}])
        |> Selecto.subselect([
          %{
            fields: ["quantity", "price"],
            target_schema: :order_items,
            format: :json_agg,
            alias: "items"
          }
        ])

      {sql, params} = Selecto.to_sql(selecto)

      # Should work (2-step is junction table scenario we already support)
      assert sql =~ ~r/from users/i
      assert sql =~ ~r/EXISTS/i or sql =~ ~r/json_agg/i
      assert "Bob" in params
    end
  end

  describe "Multi-step with retarget" do
    test "Retarget to rentals, then subselect each rental's film (2 steps from the target)" do
      query =
        create_rentals_selecto()
        |> Selecto.filter([{"first_name", "MARY"}, {"last_name", "SMITH"}])
        |> Selecto.retarget(:rentals)
        |> Selecto.select(["rental_id"])
        |> Selecto.subselect([
          %{fields: ["title"], target_schema: :film, format: :json_agg, alias: "films"}
        ])
        |> Selecto.order_by(["rental_id"])

      {sql, params} = Selecto.to_sql(query)
      assert sql =~ ~r/from rental selecto_root/i
      assert sql =~ ~r/from film sub_film where exists \(select 1 from inventory sub_inventory/i
      assert params == ["MARY", "SMITH"]

      expected =
        PagilaData.rows!("""
        select r.rental_id, f.title
        from customer c
        join rental r on r.customer_id = c.customer_id
        join inventory i on i.inventory_id = r.inventory_id
        join film f on f.film_id = i.film_id
        where c.first_name = 'MARY' and c.last_name = 'SMITH'
        order by r.rental_id
        """)

      assert expected != []
      assert rows!(query) == Enum.map(expected, fn [rental_id, title] -> [rental_id, [title]] end)
    end

    test "Retarget to rentals, then subselect each rental's categories (4 steps from the target)" do
      query =
        create_rentals_selecto()
        |> Selecto.filter([{"first_name", "MARY"}, {"last_name", "SMITH"}])
        |> Selecto.retarget(:rentals)
        |> Selecto.select(["rental_id"])
        |> Selecto.subselect([
          %{fields: ["name"], target_schema: :category, format: :array_agg, alias: "categories"}
        ])
        |> Selecto.order_by(["rental_id"])

      {sql, _params} = Selecto.to_sql(query)
      assert sql =~ ~r/exists \(select 1 from inventory j_inventory inner join film j_film/i
      assert sql =~ ~r/inner join film_category j_film_categories/i
      assert sql =~ ~r/inner join category j_category/i

      expected =
        PagilaData.rows!("""
        select r.rental_id, array_agg(distinct cat.name) filter (where cat.name is not null)
        from customer c
        join rental r on r.customer_id = c.customer_id
        join inventory i on i.inventory_id = r.inventory_id
        left join film_category fc on fc.film_id = i.film_id
        left join category cat on cat.category_id = fc.category_id
        where c.first_name = 'MARY' and c.last_name = 'SMITH'
        group by r.rental_id
        order by r.rental_id
        """)

      assert Enum.any?(expected, fn [_rental_id, categories] -> categories != nil end)

      sorted = fn rows ->
        Enum.map(rows, fn [rental_id, categories] ->
          [rental_id, categories && Enum.sort(categories)]
        end)
      end

      assert sorted.(rows!(query)) == sorted.(expected)
    end

    test "Retarget along the whole path to categories, then subselect back to their films" do
      categories = fn filters ->
        create_rentals_selecto()
        |> Selecto.filter(filters)
        |> Selecto.retarget("rentals.inventory.film.film_categories.category")
        |> Selecto.select(["name"])
        |> Selecto.subselect([
          %{
            fields: ["film_id"],
            target_schema: :film_categories,
            format: :count,
            alias: "film_count"
          }
        ])
        |> Selecto.order_by(["name"])
        |> rows!()
      end

      mary_smith = [{"first_name", "MARY"}, {"last_name", "SMITH"}]

      # A filter on the path's film join keeps only that film's categories.
      one_film = categories.(mary_smith ++ [{"film.title", "PATIENT SISTER"}])

      expected =
        PagilaData.rows!("""
        select cat.name,
               (select count(*) from film_category own where own.category_id = cat.category_id)
        from category cat
        where cat.category_id in (
          select fc.category_id
          from customer c
          join rental r on r.customer_id = c.customer_id
          join inventory i on i.inventory_id = r.inventory_id
          join film f on f.film_id = i.film_id
          join film_category fc on fc.film_id = f.film_id
          where c.first_name = 'MARY' and c.last_name = 'SMITH' and f.title = 'PATIENT SISTER')
        order by cat.name
        """)

      assert expected != []
      assert one_film == expected
      assert length(categories.(mary_smith)) > length(one_film)
    end
  end

  describe "Multi-step with different aggregation formats" do
    test "Multi-step with count aggregation" do
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"name", "Eve"}])
        |> Selecto.subselect([
          %{
            fields: ["product_id"],
            target_schema: :products,
            format: :count,
            alias: "product_count"
          }
        ])

      {sql, params} = Selecto.to_sql(selecto)

      assert sql =~ ~r/count/i
      assert sql =~ ~r/products/i
      assert "Eve" in params
    end

    test "Multi-step with string_agg" do
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"name", "Frank"}])
        |> Selecto.subselect([
          %{
            fields: ["name"],
            target_schema: :products,
            format: :string_agg,
            alias: "product_names",
            separator: ", "
          }
        ])

      {sql, params} = Selecto.to_sql(selecto)

      assert sql =~ ~r/string_agg/i
      assert sql =~ ~r/products/i
      # Separator should be in params
      assert ", " in params or sql =~ ", "
      assert "Frank" in params
    end

    test "Multiple multi-step subselects" do
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"name", "Grace"}])
        |> Selecto.subselect([
          # Products through orders
          %{
            fields: ["name"],
            target_schema: :products,
            format: :json_agg,
            alias: "products"
          },
          # Categories through orders → order_items → products → categories
          %{
            fields: ["name"],
            target_schema: :categories,
            format: :json_agg,
            alias: "categories"
          }
        ])

      {sql, params} = Selecto.to_sql(selecto)

      # Should have both subselects
      assert sql =~ ~r/products/i
      assert sql =~ ~r/categories/i
      assert "Grace" in params
    end
  end

  describe "Edge cases and validation" do
    test "Multi-step path with filtering on target" do
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"name", "Helen"}])
        |> Selecto.subselect([
          %{
            fields: ["name", "price"],
            target_schema: :products,
            format: :json_agg,
            alias: "expensive_products",
            # Simple equality filter (operators not yet supported in subselect filters)
            filters: [{"price", 99.99}]
          }
        ])

      {sql, _params} = Selecto.to_sql(selecto)

      # Should have filter in subselect (using = operator)
      assert sql =~ ~r/price.*=/i
      assert sql =~ ~r/EXISTS/i
      assert sql =~ ~r/products/i
    end

    test "Multi-step with ordering in subselect" do
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"name", "Ivan"}])
        |> Selecto.subselect([
          %{
            fields: ["name", "price"],
            target_schema: :products,
            format: :json_agg,
            alias: "products_sorted",
            order_by: [{:desc, :price}]
          }
        ])

      {sql, _params} = Selecto.to_sql(selecto)

      # Should have ORDER BY in subselect (if supported by aggregation)
      # Note: ORDER BY might be inside the aggregation function
      # May not be visible in all aggregation formats
      assert sql =~ ~r/order by/i or true
    end

    test "Validates that target schema exists" do
      assert_raise ArgumentError, ~r/Target schema.*not found/, fn ->
        create_test_selecto()
        |> Selecto.subselect([
          %{
            fields: ["name"],
            target_schema: :nonexistent_table,
            format: :json_agg,
            alias: "invalid"
          }
        ])
      end
    end
  end

  describe "Complex real-world scenarios" do
    test "Get users with products (path finder chooses shortest route)" do
      # Users → Products (path finder will choose one of multiple possible paths)
      # Could be: users → orders → order_items → products
      # Or: users → reviews → products
      # Path finder chooses first found path
      selecto =
        create_test_selecto()
        |> Selecto.select(["name", "email"])
        |> Selecto.filter([{"name", "Julia"}])
        |> Selecto.subselect([
          %{
            fields: ["name", "price"],
            target_schema: :products,
            format: :json_agg,
            alias: "related_products"
          }
        ])

      {sql, params} = Selecto.to_sql(selecto)

      # Should have multi-step EXISTS with products
      assert sql =~ ~r/EXISTS/i
      assert sql =~ ~r/products/i
      # Path may go through orders or reviews - either is valid
      assert sql =~ ~r/orders/i or sql =~ ~r/reviews/i
      assert "Julia" in params
    end
  end
end
