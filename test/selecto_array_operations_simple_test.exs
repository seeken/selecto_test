defmodule SelectoArrayOperationsSimpleTest do
  use ExUnit.Case, async: true

  alias Selecto.Advanced.ArrayOperations
  alias Selecto.SQL.Params

  describe "Array Operations Specification" do
    test "creates array_agg specification" do
      spec = ArrayOperations.create_array_operation(:array_agg, "film.title", as: "titles")

      assert spec.operation == :array_agg
      assert spec.column == "film.title"
      assert spec.alias == "titles"
      assert spec.validated == true
    end

    test "creates array_agg with DISTINCT" do
      spec =
        ArrayOperations.create_array_operation(:array_agg, "rating",
          distinct: true,
          as: "unique_ratings"
        )

      assert spec.distinct == true
      assert spec.alias == "unique_ratings"
    end

    test "creates array_agg with ORDER BY" do
      spec =
        ArrayOperations.create_array_operation(:array_agg, "title",
          order_by: [{"release_year", :desc}],
          as: "ordered_titles"
        )

      assert spec.order_by == [{"release_year", :desc}]
    end

    test "creates string_agg specification" do
      spec =
        ArrayOperations.create_array_operation(:string_agg, "name",
          delimiter: ", ",
          as: "names_list"
        )

      assert spec.operation == :string_agg
      assert spec.options[:delimiter] == ", "
    end

    test "creates array filter specifications" do
      spec = ArrayOperations.create_array_filter(:array_contains, "tags", ["featured", "new"])

      assert spec.operation == :array_contains
      assert spec.column == "tags"
      assert spec.value == ["featured", "new"]
    end

    test "creates array size operations" do
      spec = ArrayOperations.create_array_size(:array_length, "items", 1, as: "item_count")

      assert spec.operation == :array_length
      assert spec.column == "items"
      assert spec.dimension == 1
      assert spec.alias == "item_count"
    end

    test "creates unnest operation" do
      spec = ArrayOperations.create_unnest("features", as: "feature")

      assert spec.operation == :unnest
      assert spec.column == "features"
      assert spec.alias == "feature"
    end
  end

  describe "SQL Generation" do
    test "generates ARRAY_AGG SQL" do
      spec = ArrayOperations.create_array_operation(:array_agg, "title", as: "titles")
      {sql, params} = render(spec)

      assert sql == ~s|ARRAY_AGG("selecto_root"."title") AS "titles"|
      assert params == []
    end

    test "generates ARRAY_AGG DISTINCT SQL" do
      spec =
        ArrayOperations.create_array_operation(:array_agg, "rating",
          distinct: true,
          as: "unique_ratings"
        )

      {sql, params} = render(spec)

      assert sql == ~s|ARRAY_AGG(DISTINCT "selecto_root"."rating") AS "unique_ratings"|
      assert params == []
    end

    test "generates ARRAY_AGG with ORDER BY SQL" do
      spec =
        ArrayOperations.create_array_operation(:array_agg, "title",
          order_by: [{"year", :desc}, {"title", :asc}],
          as: "ordered_titles"
        )

      {sql, params} = render(spec)

      assert sql ==
               ~s|ARRAY_AGG("selecto_root"."title" ORDER BY "selecto_root"."year" DESC, "selecto_root"."title" ASC) AS "ordered_titles"|

      assert params == []
    end

    test "generates STRING_AGG SQL" do
      spec =
        ArrayOperations.create_array_operation(:string_agg, "name",
          delimiter: ", ",
          as: "names"
        )

      {sql, params} = render(spec)

      assert sql == ~s|STRING_AGG("selecto_root"."name", $1) AS "names"|
      assert params == [", "]
    end

    test "generates array filter SQL" do
      spec = ArrayOperations.create_array_filter(:array_contains, "tags", ["new", "featured"])
      {sql, params} = render(spec)

      assert sql == ~s|"selecto_root"."tags" @> $1|
      assert params == [["new", "featured"]]
    end

    test "generates array overlap SQL" do
      spec =
        ArrayOperations.create_array_filter(:array_overlap, "categories", ["tech", "science"])

      {sql, params} = render(spec)

      assert sql == ~s|"selecto_root"."categories" && $1|
      assert params == [["tech", "science"]]
    end

    test "generates array contained SQL" do
      spec =
        ArrayOperations.create_array_filter(:array_contained, "permissions", [
          "read",
          "write",
          "admin"
        ])

      {sql, params} = render(spec)

      assert sql == ~s|"selecto_root"."permissions" <@ $1|
      assert params == [["read", "write", "admin"]]
    end

    test "generates ARRAY_LENGTH SQL" do
      spec = ArrayOperations.create_array_size(:array_length, "items", 1, as: "count")
      {sql, params} = render(spec)

      assert sql == ~s|ARRAY_LENGTH("selecto_root"."items", 1) AS "count"|
      assert params == []
    end

    test "generates CARDINALITY SQL" do
      spec = ArrayOperations.create_array_size(:cardinality, "matrix", nil, as: "total")
      {sql, params} = render(spec)

      assert sql == ~s|CARDINALITY("selecto_root"."matrix") AS "total"|
      assert params == []
    end

    test "generates UNNEST SQL" do
      spec = ArrayOperations.create_unnest("features", as: "feature")
      {sql, params} = render(spec)

      assert sql == ~s|UNNEST("selecto_root"."features") AS "feature"|
      assert params == []
    end

    test "generates UNNEST WITH ORDINALITY SQL" do
      spec = ArrayOperations.create_unnest("tags", as: "tag", with_ordinality: true)
      {sql, params} = render(spec)

      assert sql == ~s|UNNEST("selecto_root"."tags") WITH ORDINALITY AS "tag"|
      assert params == []
    end

    test "generates ARRAY_APPEND SQL" do
      spec =
        ArrayOperations.create_array_operation(:array_append, "tags",
          value: "new-tag",
          as: "updated_tags"
        )

      {sql, params} = render(spec)

      assert sql == ~s|ARRAY_APPEND("selecto_root"."tags", $1) AS "updated_tags"|
      assert params == ["new-tag"]
    end

    test "generates ARRAY_REMOVE SQL" do
      spec =
        ArrayOperations.create_array_operation(:array_remove, "tags",
          value: "deprecated",
          as: "cleaned_tags"
        )

      {sql, params} = render(spec)

      assert sql == ~s|ARRAY_REMOVE("selecto_root"."tags", $1) AS "cleaned_tags"|
      assert params == ["deprecated"]
    end

    test "generates ARRAY_TO_STRING SQL" do
      spec =
        ArrayOperations.create_array_operation(:array_to_string, "tags",
          value: ", ",
          as: "tag_string"
        )

      {sql, params} = render(spec)

      assert sql == ~s|ARRAY_TO_STRING("selecto_root"."tags", $1) AS "tag_string"|
      assert params == [", "]
    end
  end

  describe "Validation" do
    test "validates array_length requires dimension" do
      assert_raise ArrayOperations.ValidationError, fn ->
        ArrayOperations.create_array_size(:array_length, "items", nil)
      end
    end

    test "validates filter operations require value" do
      assert_raise ArrayOperations.ValidationError, fn ->
        ArrayOperations.create_array_filter(:array_contains, "tags", nil)
      end
    end

    test "validates invalid operation types" do
      assert_raise ArrayOperations.ValidationError, fn ->
        ArrayOperations.create_array_operation(:invalid_op, "column")
      end
    end
  end

  defp render(spec) do
    selecto = %Selecto{adapter: SelectoDBPostgreSQL.Adapter, config: %{}}
    {sql_iodata, _params} = ArrayOperations.to_sql(spec, [], selecto)
    Params.finalize(sql_iodata, adapter: SelectoDBPostgreSQL.Adapter)
  end
end
