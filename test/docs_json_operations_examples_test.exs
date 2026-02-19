defmodule DocsJsonOperationsExamplesTest do
  use ExUnit.Case, async: true

  @moduledoc """
  These tests demonstrate JSON operations functionality in Selecto.
  They have been updated to use the actual Selecto API.
  """

  describe "Basic JSON Operations" do
    test "JSON extraction operation can be created" do
      # Create JSON extraction operations
      json_spec1 =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_extract,
          "config",
          path: "$.theme",
          as: "theme"
        )

      json_spec2 =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_extract,
          "metadata",
          path: "$.tags",
          as: "tags"
        )

      # Verify the specs
      assert json_spec1.operation == :json_extract
      assert json_spec1.column == "config"
      assert json_spec1.path == "$.theme"
      assert json_spec1.alias == "theme"

      assert json_spec2.operation == :json_extract
      assert json_spec2.column == "metadata"
      assert json_spec2.path == "$.tags"
      assert json_spec2.alias == "tags"
    end

    test "extract JSON value as text" do
      # Create JSON extraction with text conversion
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_extract_text,
          "data",
          path: "$.brand",
          as: "brand"
        )

      # Verify the spec
      assert json_spec.operation == :json_extract_text
      assert json_spec.column == "data"
      assert json_spec.path == "$.brand"
      assert json_spec.alias == "brand"
    end

    test "extract nested values with path" do
      # Create JSON path extraction
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_extract_path,
          "data",
          path: "$.specs.dimensions.weight",
          as: "weight"
        )

      # Verify the spec
      assert json_spec.operation == :json_extract_path
      assert json_spec.column == "data"
      assert json_spec.path == "$.specs.dimensions.weight"
      assert json_spec.alias == "weight"
    end
  end

  describe "JSON Aggregation Operations" do
    test "JSON aggregation operations" do
      # Create JSON aggregation
      json_agg_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_agg,
          "product_name",
          as: "products"
        )

      # Create JSON object aggregation
      json_obj_agg_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_object_agg,
          "product_id",
          value_field: "price",
          as: "price_map"
        )

      # Verify the specs
      assert json_agg_spec.operation == :json_agg
      assert json_agg_spec.column == "product_name"
      assert json_agg_spec.alias == "products"

      assert json_obj_agg_spec.operation == :json_object_agg
      assert json_obj_agg_spec.column == "product_id"
      assert json_obj_agg_spec.value_field == "price"
      assert json_obj_agg_spec.alias == "price_map"
    end

    test "JSONB aggregation operations" do
      # Create JSONB aggregation
      jsonb_agg_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :jsonb_agg,
          "item_data",
          as: "items"
        )

      # Verify the spec
      assert jsonb_agg_spec.operation == :jsonb_agg
      assert jsonb_agg_spec.column == "item_data"
      assert jsonb_agg_spec.alias == "items"
    end
  end

  describe "JSON Testing and Filtering Operations" do
    test "JSON contains operator" do
      # Create JSON contains operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_contains,
          "metadata",
          value: %{"category" => "electronics"}
        )

      # Verify the spec
      assert json_spec.operation == :json_contains
      assert json_spec.column == "metadata"
      assert json_spec.value == %{"category" => "electronics"}
    end

    test "JSON is contained by operator" do
      # Create JSON contained operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_contained,
          "preferences",
          value: %{"theme" => "dark", "language" => "en"}
        )

      # Verify the spec
      assert json_spec.operation == :json_contained
      assert json_spec.column == "preferences"
      assert json_spec.value == %{"theme" => "dark", "language" => "en"}
    end

    test "JSON path exists operator" do
      # Create JSON path exists operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_path_exists,
          "data",
          path: "$.specifications.warranty"
        )

      # Verify the spec
      assert json_spec.operation == :json_path_exists
      assert json_spec.column == "data"
      assert json_spec.path == "$.specifications.warranty"
    end

    test "JSON key exists operator" do
      # Create JSON key exists operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_exists,
          "data",
          value: "specifications"
        )

      # Verify the spec
      assert json_spec.operation == :json_exists
      assert json_spec.column == "data"
      assert json_spec.value == "specifications"
    end
  end

  describe "JSON SQL Generation" do
    test "JSON extraction generates correct SQL" do
      # Create and validate a JSON extraction spec
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_extract,
          "metadata",
          path: "$.name",
          as: "name"
        )

      {:ok, validated_spec} = Selecto.Advanced.JsonOperations.validate_json_operation(json_spec)

      # Build SQL for the operation
      sql_iodata = Selecto.Builder.JsonOperations.build_json_select(validated_spec)
      sql_string = IO.iodata_to_binary(sql_iodata)

      # Verify SQL structure
      assert sql_string =~ "metadata"
      assert sql_string =~ "->"
      assert sql_string =~ "AS"
    end

    test "JSON text extraction generates correct SQL" do
      # Create and validate a JSON text extraction spec
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_extract_text,
          "config",
          path: "$.theme",
          as: "theme"
        )

      {:ok, validated_spec} = Selecto.Advanced.JsonOperations.validate_json_operation(json_spec)

      # Build SQL for the operation
      sql_iodata = Selecto.Builder.JsonOperations.build_json_select(validated_spec)
      sql_string = IO.iodata_to_binary(sql_iodata)

      # Verify SQL structure (text extraction uses ->>)
      assert sql_string =~ "config"
      assert sql_string =~ "->>"
      assert sql_string =~ "AS"
    end

    test "JSON aggregation generates correct SQL" do
      # Create and validate a JSON aggregation spec
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_agg,
          "product_name",
          as: "products"
        )

      {:ok, validated_spec} = Selecto.Advanced.JsonOperations.validate_json_operation(json_spec)

      # Build SQL for the operation
      sql_iodata = Selecto.Builder.JsonOperations.build_json_select(validated_spec)
      sql_string = IO.iodata_to_binary(sql_iodata)

      # Verify SQL structure
      assert sql_string =~ "JSON_AGG"
      assert sql_string =~ "product_name"
      assert sql_string =~ "AS"
    end

    test "JSON filter operation generates correct SQL" do
      # Create and validate a JSON contains spec
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_contains,
          "metadata",
          value: %{"active" => true}
        )

      {:ok, validated_spec} = Selecto.Advanced.JsonOperations.validate_json_operation(json_spec)

      # Build SQL for filtering
      sql_iodata = Selecto.Builder.JsonOperations.build_json_filter(validated_spec)
      sql_string = IO.iodata_to_binary(sql_iodata)

      # Verify SQL structure
      assert sql_string =~ "metadata"
      assert sql_string =~ "@>"
    end
  end

  describe "JSON Type Operations" do
    test "JSON type checking operations" do
      # Create JSON typeof operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_typeof,
          "data",
          as: "data_type"
        )

      # Verify the spec
      assert json_spec.operation == :json_typeof
      assert json_spec.column == "data"
      assert json_spec.alias == "data_type"
    end

    test "JSON array length operation" do
      # Create JSON array length operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_array_length,
          "items",
          as: "item_count"
        )

      # Verify the spec
      assert json_spec.operation == :json_array_length
      assert json_spec.column == "items"
      assert json_spec.alias == "item_count"
    end

    test "JSONB array length operation" do
      # Create JSONB array length operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :jsonb_array_length,
          "tags",
          as: "tag_count"
        )

      # Verify the spec
      assert json_spec.operation == :jsonb_array_length
      assert json_spec.column == "tags"
      assert json_spec.alias == "tag_count"
    end
  end

  describe "JSON Manipulation Operations" do
    test "JSON set operation" do
      # Create JSON set operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :jsonb_set,
          "config",
          path: "$.theme",
          value: "dark",
          as: "updated_config"
        )

      # Verify the spec
      assert json_spec.operation == :jsonb_set
      assert json_spec.column == "config"
      assert json_spec.path == "$.theme"
      assert json_spec.value == "dark"
      assert json_spec.alias == "updated_config"
    end

    test "JSON delete operation" do
      # Create JSON delete operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :jsonb_delete,
          "metadata",
          value: "deprecated_field",
          as: "cleaned_metadata"
        )

      # Verify the spec
      assert json_spec.operation == :jsonb_delete
      assert json_spec.column == "metadata"
      assert json_spec.value == "deprecated_field"
      assert json_spec.alias == "cleaned_metadata"
    end

    test "JSON delete path operation" do
      # Create JSON delete path operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :jsonb_delete_path,
          "data",
          path: "$.temp.cache",
          as: "cleaned_data"
        )

      # Verify the spec
      assert json_spec.operation == :jsonb_delete_path
      assert json_spec.column == "data"
      assert json_spec.path == "$.temp.cache"
      assert json_spec.alias == "cleaned_data"
    end
  end

  describe "JSON Construction Operations" do
    test "JSON build object operation" do
      # Create JSON build object operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :json_build_object,
          # No source column for construction
          nil,
          value: ["key1", "value1", "key2", "value2"],
          as: "custom_object"
        )

      # Verify the spec
      assert json_spec.operation == :json_build_object
      assert json_spec.value == ["key1", "value1", "key2", "value2"]
      assert json_spec.alias == "custom_object"
    end

    test "JSONB build array operation" do
      # Create JSONB build array operation
      json_spec =
        Selecto.Advanced.JsonOperations.create_json_operation(
          :jsonb_build_array,
          # No source column for construction
          nil,
          value: ["item1", "item2", "item3"],
          as: "custom_array"
        )

      # Verify the spec
      assert json_spec.operation == :jsonb_build_array
      assert json_spec.value == ["item1", "item2", "item3"]
      assert json_spec.alias == "custom_array"
    end
  end
end
