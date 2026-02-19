defmodule SelectoTest.TestHelpers do
  @moduledoc """
  Helper functions for configuring Selecto in tests.
  """

  def configure_test_selecto(table_name \\ "film") do
    domain = get_test_domain(table_name)
    connection = get_test_connection()
    Selecto.configure(domain, connection, validate: false)
  end

  def get_test_domain(table_name \\ "film") do
    # Convert atom to string if needed
    table_name_str = if is_atom(table_name), do: Atom.to_string(table_name), else: table_name

    %{
      # Add domain name
      name: String.capitalize(table_name_str),
      source: get_source_for_table(table_name_str),
      schemas: get_all_schemas(),
      # Empty joins for test simplicity
      joins: %{}
    }
  end

  def get_test_connection do
    :test_connection
  end

  defp get_source_for_table(table_name) do
    # Get the schema for this table to extract fields and columns
    schema = get_schema_for_table(table_name)

    base_source =
      case table_name do
        "film" ->
          %{
            source_table: "film",
            primary_key: :film_id
          }

        "product" ->
          %{
            source_table: "product",
            primary_key: :product_id
          }

        "customer" ->
          %{
            source_table: "customer",
            primary_key: :customer_id
          }

        "orders" ->
          %{
            source_table: "orders",
            primary_key: :order_id
          }

        "rental" ->
          %{
            source_table: "rental",
            primary_key: :rental_id
          }

        _ ->
          %{
            source_table: table_name,
            primary_key: :id
          }
      end

    # Merge in fields and columns from schema
    Map.merge(base_source, Map.take(schema, [:fields, :columns, :redact_fields, :associations]))
  end

  defp get_schema_for_table(table_name) do
    case table_name do
      "film" ->
        film_schema()

      "actor" ->
        actor_schema()

      "customer" ->
        customer_schema()

      "product" ->
        product_schema()

      "employee" ->
        employee_schema()

      "orders" ->
        orders_schema()

      "rental" ->
        rental_schema()

      _ ->
        # Default schema structure
        %{
          source_table: table_name,
          primary_key: :id,
          fields: [:id],
          redact_fields: [],
          columns: %{id: %{type: :integer}},
          associations: %{}
        }
    end
  end

  defp get_all_schemas do
    %{
      film: film_schema(),
      actor: actor_schema(),
      category: category_schema(),
      customer: customer_schema(),
      rental: rental_schema(),
      payment: payment_schema(),
      inventory: inventory_schema(),
      orders: orders_schema(),
      order_items: order_items_schema(),
      product: product_schema(),
      employee: employee_schema(),
      store: store_schema(),
      staff: staff_schema()
    }
  end

  defp film_schema do
    %{
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
        :rating,
        :last_update,
        :special_features,
        :fulltext,
        :category,
        :tags,
        :metadata,
        :specifications
      ],
      redact_fields: [],
      columns: %{
        film_id: %{type: :integer},
        title: %{type: :string},
        description: %{type: :text},
        release_year: %{type: :integer},
        language_id: %{type: :integer},
        rental_duration: %{type: :integer},
        rental_rate: %{type: :decimal},
        length: %{type: :integer},
        replacement_cost: %{type: :decimal},
        rating: %{type: :string},
        last_update: %{type: :datetime},
        special_features: %{type: {:array, :string}},
        fulltext: %{type: :text},
        category: %{type: :string},
        tags: %{type: {:array, :string}},
        metadata: %{type: :map},
        specifications: %{type: {:array, :map}}
      },
      associations: %{}
    }
  end

  defp actor_schema do
    %{
      source_table: "actor",
      primary_key: :actor_id,
      fields: [:actor_id, :first_name, :last_name, :last_update],
      redact_fields: [],
      columns: %{
        actor_id: %{type: :integer},
        first_name: %{type: :string},
        last_name: %{type: :string},
        last_update: %{type: :datetime}
      },
      associations: %{}
    }
  end

  defp category_schema do
    %{
      source_table: "category",
      primary_key: :category_id,
      fields: [:category_id, :name, :last_update],
      redact_fields: [],
      columns: %{
        category_id: %{type: :integer},
        name: %{type: :string},
        last_update: %{type: :datetime}
      },
      associations: %{}
    }
  end

  defp customer_schema do
    %{
      source_table: "customer",
      primary_key: :customer_id,
      fields: [
        :customer_id,
        :store_id,
        :first_name,
        :last_name,
        :email,
        :address_id,
        :activebool,
        :create_date,
        :last_update,
        :active,
        :preferences,
        :created_at
      ],
      redact_fields: [],
      columns: %{
        customer_id: %{type: :integer},
        store_id: %{type: :integer},
        first_name: %{type: :string},
        last_name: %{type: :string},
        email: %{type: :string},
        address_id: %{type: :integer},
        activebool: %{type: :boolean},
        create_date: %{type: :date},
        last_update: %{type: :datetime},
        active: %{type: :integer},
        preferences: %{type: :map},
        created_at: %{type: :datetime}
      },
      associations: %{}
    }
  end

  defp rental_schema do
    %{
      source_table: "rental",
      primary_key: :rental_id,
      fields: [
        :rental_id,
        :rental_date,
        :inventory_id,
        :customer_id,
        :return_date,
        :staff_id,
        :last_update,
        :amount
      ],
      redact_fields: [],
      columns: %{
        rental_id: %{type: :integer},
        rental_date: %{type: :datetime},
        inventory_id: %{type: :integer},
        customer_id: %{type: :integer},
        return_date: %{type: :datetime},
        staff_id: %{type: :integer},
        last_update: %{type: :datetime},
        amount: %{type: :decimal}
      },
      associations: %{}
    }
  end

  defp payment_schema do
    %{
      source_table: "payment",
      primary_key: :payment_id,
      fields: [:payment_id, :customer_id, :staff_id, :rental_id, :amount, :payment_date],
      redact_fields: [],
      columns: %{
        payment_id: %{type: :integer},
        customer_id: %{type: :integer},
        staff_id: %{type: :integer},
        rental_id: %{type: :integer},
        amount: %{type: :decimal},
        payment_date: %{type: :datetime}
      },
      associations: %{}
    }
  end

  defp inventory_schema do
    %{
      source_table: "inventory",
      primary_key: :inventory_id,
      fields: [:inventory_id, :film_id, :store_id, :last_update],
      redact_fields: [],
      columns: %{
        inventory_id: %{type: :integer},
        film_id: %{type: :integer},
        store_id: %{type: :integer},
        last_update: %{type: :datetime}
      },
      associations: %{}
    }
  end

  defp orders_schema do
    %{
      source_table: "orders",
      primary_key: :order_id,
      fields: [:order_id, :customer_id, :order_date, :status, :total, :metadata, :items],
      redact_fields: [],
      columns: %{
        order_id: %{type: :integer},
        customer_id: %{type: :integer},
        order_date: %{type: :date},
        status: %{type: :string},
        total: %{type: :decimal},
        metadata: %{type: :map},
        items: %{type: {:array, :map}}
      },
      associations: %{}
    }
  end

  defp order_items_schema do
    %{
      source_table: "order_items",
      primary_key: [:order_id, :line_number],
      fields: [:order_id, :line_number, :product_id, :product_name, :quantity, :price],
      redact_fields: [],
      columns: %{
        order_id: %{type: :integer},
        line_number: %{type: :integer},
        product_id: %{type: :integer},
        product_name: %{type: :string},
        quantity: %{type: :integer},
        price: %{type: :decimal}
      },
      associations: %{}
    }
  end

  defp product_schema do
    %{
      source_table: "product",
      primary_key: :product_id,
      fields: [
        :product_id,
        :name,
        :category,
        :price,
        :tags,
        :metadata,
        :settings,
        :config_json,
        :config_jsonb,
        :attributes,
        :specifications,
        :data
      ],
      redact_fields: [],
      columns: %{
        product_id: %{type: :integer},
        name: %{type: :string},
        category: %{type: :string},
        price: %{type: :decimal},
        tags: %{type: {:array, :string}},
        metadata: %{type: :map},
        settings: %{type: :map},
        config_json: %{type: :map},
        config_jsonb: %{type: :map},
        attributes: %{type: :map},
        specifications: %{type: :map},
        data: %{type: :map}
      },
      associations: %{}
    }
  end

  defp employee_schema do
    %{
      source_table: "employee",
      primary_key: :employee_id,
      fields: [:employee_id, :name, :department, :manager_id, :salary, :hire_date],
      redact_fields: [],
      columns: %{
        employee_id: %{type: :integer},
        name: %{type: :string},
        department: %{type: :string},
        manager_id: %{type: :integer},
        salary: %{type: :decimal},
        hire_date: %{type: :date}
      },
      associations: %{}
    }
  end

  defp store_schema do
    %{
      source_table: "store",
      primary_key: :store_id,
      fields: [:store_id, :manager_staff_id, :address_id, :last_update],
      redact_fields: [],
      columns: %{
        store_id: %{type: :integer},
        manager_staff_id: %{type: :integer},
        address_id: %{type: :integer},
        last_update: %{type: :datetime}
      },
      associations: %{}
    }
  end

  defp staff_schema do
    %{
      source_table: "staff",
      primary_key: :staff_id,
      fields: [
        :staff_id,
        :first_name,
        :last_name,
        :address_id,
        :email,
        :store_id,
        :active,
        :username,
        :password,
        :last_update,
        :picture
      ],
      redact_fields: [],
      columns: %{
        staff_id: %{type: :integer},
        first_name: %{type: :string},
        last_name: %{type: :string},
        address_id: %{type: :integer},
        email: %{type: :string},
        store_id: %{type: :integer},
        active: %{type: :boolean},
        username: %{type: :string},
        password: %{type: :string},
        last_update: %{type: :datetime},
        picture: %{type: :binary}
      },
      associations: %{}
    }
  end

  # defp get_joins_config do
  #   %{
  #     "actor" => %{
  #       type: :inner,
  #       through: "film_actor",
  #       on: "film.film_id = film_actor.film_id AND film_actor.actor_id = actor.actor_id"
  #     },
  #     "category" => %{
  #       type: :inner,
  #       through: "film_category",
  #       on: "film.film_id = film_category.film_id AND film_category.category_id = category.category_id"
  #     },
  #     "inventory" => %{
  #       type: :inner,
  #       on: "film.film_id = inventory.film_id"
  #     },
  #     "rental" => %{
  #       type: :inner,
  #       through: "inventory",
  #       on: "film.film_id = inventory.film_id AND inventory.inventory_id = rental.inventory_id"
  #     },
  #     "customer" => %{
  #       type: :inner,
  #       through: "rental",
  #       on: "rental.customer_id = customer.customer_id"
  #     },
  #     "payment" => %{
  #       type: :inner,
  #       on: "rental.rental_id = payment.rental_id"
  #     },
  #     "order_items" => %{
  #       type: :inner,
  #       on: "orders.order_id = order_items.order_id"
  #     }
  #   }
  # end
end
