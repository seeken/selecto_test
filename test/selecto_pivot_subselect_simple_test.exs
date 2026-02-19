defmodule SelectoPivotSubselectSimpleTest do
  use ExUnit.Case, async: true

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
    domain = simple_domain()
    postgrex_opts = [hostname: "localhost", username: "test"]
    Selecto.configure(domain, postgrex_opts, validate: false)
  end

  describe "Pivot feature SQL generation" do
    test "basic pivot generates correct SQL structure" do
      selecto =
        create_test_selecto()
        |> Selecto.filter([{"name", "Alice"}])
        |> Selecto.pivot(:posts)
        |> Selecto.select(["posts.title", "posts.content"])

      {sql, params} = Selecto.to_sql(selecto)

      # Should pivot to posts table
      assert sql =~ "from posts"

      # Should contain subquery structure
      assert sql =~ "IN (" or sql =~ "EXISTS ("

      # Should contain original table in subquery
      assert sql =~ "users"

      # Should have parameter for filter
      assert "Alice" in params
    end

    test "different pivot strategies produce different SQL" do
      base_selecto =
        create_test_selecto()
        |> Selecto.filter([{"name", "Bob"}])
        |> Selecto.select(["posts.title"])

      # IN strategy
      in_selecto = base_selecto |> Selecto.pivot(:posts, subquery_strategy: :in)
      {in_sql, _} = Selecto.to_sql(in_selecto)

      # EXISTS strategy
      exists_selecto = base_selecto |> Selecto.pivot(:posts, subquery_strategy: :exists)
      {exists_sql, _} = Selecto.to_sql(exists_selecto)

      # Should have different patterns
      assert in_sql =~ "IN ("
      assert exists_sql =~ "EXISTS ("
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
      assert json_sql =~ "json_agg"
      assert array_sql =~ "array_agg"
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

  describe "Combined Pivot and Subselect features" do
    test "pivot with subselects generates correct SQL" do
      selecto =
        create_test_selecto()
        |> Selecto.filter([{"name", "Charlie"}])
        |> Selecto.pivot(:posts)
        |> Selecto.select(["posts.title", "posts.content"])
        |> Selecto.subselect([
          %{
            fields: ["name", "email"],
            # Back-reference to users
            target_schema: :users,
            format: :json_agg,
            alias: "authors"
          }
        ])

      {sql, params} = Selecto.to_sql(selecto)

      # Should have pivot structure (from posts)
      assert sql =~ "from posts"

      # Should have pivot subquery
      assert sql =~ "IN (" or sql =~ "EXISTS ("

      # Should have subselect
      assert sql =~ "json_agg"

      # Should have filter parameter
      assert "Charlie" in params
    end
  end

  describe "Feature validation" do
    test "pivot validates target schema exists" do
      assert_raise ArgumentError, ~r/Invalid pivot configuration/, fn ->
        create_test_selecto()
        |> Selecto.pivot(:invalid_schema)
      end
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
    test "pivot API functions work correctly" do
      selecto = create_test_selecto()

      # Initially no pivot
      refute Selecto.Pivot.has_pivot?(selecto)
      assert Selecto.Pivot.get_pivot_config(selecto) == nil

      # Add pivot
      pivoted = Selecto.pivot(selecto, :posts)
      assert Selecto.Pivot.has_pivot?(pivoted)

      config = Selecto.Pivot.get_pivot_config(pivoted)
      assert config.target_schema == :posts
      assert config.preserve_filters == true

      # Reset pivot
      reset = Selecto.Pivot.reset_pivot(pivoted)
      refute Selecto.Pivot.has_pivot?(reset)
    end

    test "subselect API functions work correctly" do
      selecto = create_test_selecto()

      # Initially no subselects
      refute Selecto.Subselect.has_subselects?(selecto)
      assert Selecto.Subselect.get_subselect_configs(selecto) == []

      # Add subselects
      subselected = Selecto.subselect(selecto, ["posts[title]"])
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
