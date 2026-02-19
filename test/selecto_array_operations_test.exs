defmodule SelectoArrayOperationsTest do
  use ExUnit.Case, async: true

  describe "Array Aggregation Operations" do
    test "ARRAY_AGG operation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.array_select({:array_agg, "title", as: "film_titles"})
        |> Selecto.group_by(["rating"])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/ARRAY_AGG\("?selecto_root"?\."?title"?\) AS film_titles/
      assert sql =~ ~r/group by/i
    end

    test "ARRAY_AGG with DISTINCT" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["release_year"])
        |> Selecto.array_select({:array_agg_distinct, "rating", as: "unique_ratings"})
        |> Selecto.group_by(["release_year"])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/ARRAY_AGG\(DISTINCT "?selecto_root"?\."?rating"?\) AS unique_ratings/
    end

    test "ARRAY_AGG with ORDER BY" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.array_select(
          {:array_agg, "title",
           order_by: [{"release_year", :desc}, {"title", :asc}], as: "films_chronological"}
        )
        |> Selecto.group_by(["rating"])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~
               ~r/ARRAY_AGG\("?selecto_root"?\."?title"? ORDER BY "?selecto_root"?\."?release_year"? DESC, "?selecto_root"?\."?title"? ASC\) AS films_chronological/
    end

    test "STRING_AGG operation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.array_select(
          {:string_agg, "title", delimiter: ", ", order_by: [{"title", :asc}], as: "title_list"}
        )
        |> Selecto.group_by(["rating"])

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~
               ~r/STRING_AGG\("?selecto_root"?\."?title"?, \$1 ORDER BY "?selecto_root"?\."?title"? ASC\) AS title_list/

      assert params == [", "]
    end
  end

  describe "Array Filtering Operations" do
    test "ARRAY_CONTAINS filter" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title", "special_features"])
        |> Selecto.array_filter({:array_contains, "special_features", ["Trailers"]})

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/"?selecto_root"?\."?special_features"? @> \$1/
      assert params == [["Trailers"]]
    end

    test "ARRAY_OVERLAP filter" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_filter(
          {:array_overlap, "special_features", ["Commentary", "Deleted Scenes"]}
        )

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/"?selecto_root"?\."?special_features"? && \$1/
      assert params == [["Commentary", "Deleted Scenes"]]
    end

    test "ARRAY_CONTAINED filter" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_filter(
          {:array_contained, "special_features",
           ["Trailers", "Commentary", "Deleted Scenes", "Behind the Scenes"]}
        )

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/"?selecto_root"?\."?special_features"? <@ \$1/
      assert params == [["Trailers", "Commentary", "Deleted Scenes", "Behind the Scenes"]]
    end

    test "Multiple array filters combined" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title", "rating"])
        |> Selecto.array_filter({:array_contains, "special_features", ["Commentary"]})
        |> Selecto.filter([{"rating", "PG"}])

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      # Parameters are ordered based on where they appear in WHERE clause
      # Regular filter comes first, then array filter
      assert sql =~ ~r/"?selecto_root"?\."?special_features"? @> \$2/
      assert sql =~ ~r/"?selecto_root"?\."?rating"? = \$1/
      assert params == ["PG", ["Commentary"]]
    end
  end

  describe "Array Size Operations" do
    test "CARDINALITY operation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select({:cardinality, "special_features", as: "total_features"})

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/CARDINALITY\("?selecto_root"?\."?special_features"?\) AS total_features/
    end

    test "ARRAY_LENGTH operation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select({:array_length, "special_features", 1, as: "feature_count"})

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/ARRAY_LENGTH\("?selecto_root"?\."?special_features"?, 1\) AS feature_count/
    end

    test "ARRAY_NDIMS operation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select({:array_ndims, "special_features", as: "dimensions"})

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/ARRAY_NDIMS\("?selecto_root"?\."?special_features"?\) AS dimensions/
    end
  end

  describe "Array Construction Operations" do
    test "ARRAY constructor" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select({:array, ["Action", "Drama", "Comedy"], as: "genres"})

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ "ARRAY[$1, $2, $3] AS genres"
      assert params == ["Action", "Drama", "Comedy"]
    end
  end

  describe "Array Manipulation Operations" do
    test "ARRAY_APPEND operation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select(
          {:array_append, "special_features", "Extended Cut", as: "enhanced_features"}
        )

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~
               ~r/ARRAY_APPEND\("?selecto_root"?\."?special_features"?, \$1\) AS enhanced_features/

      assert params == ["Extended Cut"]
    end

    test "ARRAY_REMOVE operation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select(
          {:array_remove, "special_features", "Trailers", as: "features_no_trailers"}
        )

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~
               ~r/ARRAY_REMOVE\("?selecto_root"?\."?special_features"?, \$1\) AS features_no_trailers/

      assert params == ["Trailers"]
    end

    test "ARRAY_TO_STRING operation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select(
          {:array_to_string, "special_features", " | ", as: "features_text"}
        )

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~
               ~r/ARRAY_TO_STRING\("?selecto_root"?\."?special_features"?, \$1\) AS features_text/

      assert params == [" | "]
    end

    test "STRING_TO_ARRAY operation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["title"])
        |> Selecto.array_select({:string_to_array, "description", " ", as: "description_words"})

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~
               ~r/STRING_TO_ARRAY\("?selecto_root"?\."?description"?, \$1\) AS description_words/

      assert params == [" "]
    end
  end

  describe "Complex Array Scenarios" do
    test "Combining array aggregation with filters and manipulation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["rating"])
        |> Selecto.array_select([
          {:array_agg, "title", order_by: [{"title", :asc}], as: "film_list"},
          {:array_length, {:array_agg, "film_id"}, 1, as: "film_count"}
        ])
        |> Selecto.array_filter({:array_contains, "special_features", ["Commentary"]})
        |> Selecto.group_by(["rating"])

      {sql, _aliases, params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~
               ~r/ARRAY_AGG\("?selecto_root"?\."?title"? ORDER BY "?selecto_root"?\."?title"? ASC\) AS film_list/

      assert sql =~
               ~r/ARRAY_LENGTH\(ARRAY_AGG\("?selecto_root"?\."?film_id"?\), 1\) AS film_count/

      assert sql =~ ~r/"?selecto_root"?\."?special_features"? @> \$1/
      assert sql =~ ~r/group by/i
      assert params == [["Commentary"]]
    end

    test "UNNEST with joins and aggregation" do
      selecto = configure_test_selecto()

      result =
        selecto
        |> Selecto.select(["feature", {:count, "*"}])
        |> Selecto.unnest("special_features", as: "feature")
        |> Selecto.group_by(["feature"])

      {sql, _aliases, _params} = Selecto.Builder.Sql.build(result, [])

      assert sql =~ ~r/select.*feature.*count\(\*\)/i
      assert sql =~ ~r/from\s+(\")?film(\")?/i
      assert sql =~ "UNNEST"
      assert sql =~ "AS feature"
      assert sql =~ ~r/group by.*feature/i
    end
  end

  # Helper function to configure test Selecto instance
  defp configure_test_selecto do
    domain = get_test_domain()
    connection = get_test_connection()
    Selecto.configure(domain, connection, validate: false)
  end

  defp get_test_domain do
    %{
      name: "Film",
      source: %{
        source_table: "film",
        primary_key: :film_id,
        fields: [:film_id, :title, :description, :release_year, :rating, :special_features],
        redact_fields: [],
        columns: %{
          film_id: %{type: :integer},
          title: %{type: :string},
          description: %{type: :text},
          release_year: %{type: :integer},
          rating: %{type: :string},
          special_features: %{type: {:array, :string}}
        },
        associations: %{}
      },
      schemas: %{
        category: %{
          source_table: "category",
          primary_key: :category_id,
          fields: [:category_id, :name],
          redact_fields: [],
          columns: %{
            category_id: %{type: :integer},
            name: %{type: :string}
          },
          associations: %{}
        },
        film_category: %{
          source_table: "film_category",
          primary_key: [:film_id, :category_id],
          fields: [:film_id, :category_id],
          redact_fields: [],
          columns: %{
            film_id: %{type: :integer},
            category_id: %{type: :integer}
          },
          associations: %{}
        },
        actor: %{
          source_table: "actor",
          primary_key: :actor_id,
          fields: [:actor_id, :first_name, :last_name],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            first_name: %{type: :string},
            last_name: %{type: :string}
          },
          associations: %{}
        },
        film_actor: %{
          source_table: "film_actor",
          primary_key: [:actor_id, :film_id],
          fields: [:actor_id, :film_id],
          redact_fields: [],
          columns: %{
            actor_id: %{type: :integer},
            film_id: %{type: :integer}
          },
          associations: %{}
        },
        customer: %{
          source_table: "customer",
          primary_key: :customer_id,
          fields: [:customer_id, :first_name, :last_name],
          redact_fields: [],
          columns: %{
            customer_id: %{type: :integer},
            first_name: %{type: :string},
            last_name: %{type: :string}
          },
          associations: %{}
        },
        rental: %{
          source_table: "rental",
          primary_key: :rental_id,
          fields: [:rental_id, :customer_id, :inventory_id],
          redact_fields: [],
          columns: %{
            rental_id: %{type: :integer},
            customer_id: %{type: :integer},
            inventory_id: %{type: :integer}
          },
          associations: %{}
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
          associations: %{}
        }
      },
      joins: %{}
    }
  end

  defp get_test_connection do
    []
  end
end
