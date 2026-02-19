defmodule Selecto.Output.Transformers.JsonTest do
  use ExUnit.Case, async: true

  alias Selecto.Output.Transformers.Json
  alias Selecto.Error

  describe "transform/4" do
    test "transforms simple rows to JSON" do
      rows = [
        ["John", 25, "Engineer"],
        ["Jane", 30, "Designer"]
      ]

      columns = ["name", "age", "role"]
      aliases = %{}

      assert {:ok, json} = Json.transform(rows, columns, aliases, [])

      # Parse to verify valid JSON
      assert {:ok, data} = Jason.decode(json)
      assert length(data) == 2
      assert %{"name" => "John", "age" => 25, "role" => "Engineer"} = Enum.at(data, 0)
      assert %{"name" => "Jane", "age" => 30, "role" => "Designer"} = Enum.at(data, 1)
    end

    test "transforms with column aliases" do
      rows = [["John", 25]]
      columns = ["name", "years"]
      aliases = %{"years" => "age"}

      assert {:ok, json} = Json.transform(rows, columns, aliases, [])
      assert {:ok, [data]} = Jason.decode(json)
      assert %{"name" => "John", "age" => 25} = data
    end

    test "handles empty results" do
      rows = []
      columns = ["name", "age"]
      aliases = %{}

      assert {:ok, json} = Json.transform(rows, columns, aliases, [])
      assert {:ok, []} = Jason.decode(json)
    end

    test "handles nil values with default null handling" do
      rows = [["John", nil, "Engineer"]]
      columns = ["name", "age", "role"]
      aliases = %{}

      assert {:ok, json} = Json.transform(rows, columns, aliases, [])
      assert {:ok, [data]} = Jason.decode(json)
      assert %{"name" => "John", "age" => nil, "role" => "Engineer"} = data
    end

    test "omits null values with null_handling: :omit" do
      rows = [["John", nil, "Engineer"]]
      columns = ["name", "age", "role"]
      aliases = %{}

      assert {:ok, json} = Json.transform(rows, columns, aliases, null_handling: :omit)
      assert {:ok, [data]} = Jason.decode(json)
      assert %{"name" => "John", "role" => "Engineer"} = data
      refute Map.has_key?(data, "age")
    end

    test "converts null values to empty strings with null_handling: :empty_string" do
      rows = [["John", nil, "Engineer"]]
      columns = ["name", "age", "role"]
      aliases = %{}

      assert {:ok, json} = Json.transform(rows, columns, aliases, null_handling: :empty_string)
      assert {:ok, [data]} = Jason.decode(json)
      assert %{"name" => "John", "age" => "", "role" => "Engineer"} = data
    end

    test "includes metadata when requested" do
      rows = [["John", 25]]
      columns = ["name", "age"]
      aliases = %{"name" => "full_name"}

      assert {:ok, json} = Json.transform(rows, columns, aliases, include_meta: true)
      assert {:ok, response} = Jason.decode(json)

      assert %{"data" => data, "meta" => _meta} = response
      assert length(data) == 1

      assert %{
               "meta" => %{
                 "total_rows" => 1,
                 "columns" => ["name", "age"],
                 "aliases" => %{"name" => "full_name"},
                 "generated_at" => _timestamp
               }
             } = response
    end

    test "uses atom keys when specified" do
      rows = [["John", 25]]
      columns = ["name", "age"]
      aliases = %{}

      assert {:ok, json} = Json.transform(rows, columns, aliases, keys: :atoms)
      assert {:ok, [data]} = Jason.decode(json, keys: :atoms)
      assert %{name: "John", age: 25} = data
    end

    test "pretty prints JSON when requested" do
      rows = [["John", 25]]
      columns = ["name", "age"]
      aliases = %{}

      assert {:ok, json} = Json.transform(rows, columns, aliases, pretty: true)
      # Pretty printed JSON should contain newlines and indentation
      assert String.contains?(json, "\n")
      assert String.contains?(json, "  ")
    end

    test "handles type coercion with decimals" do
      # Create a mock decimal value
      decimal_value =
        if Code.ensure_loaded?(Decimal) do
          Decimal.new("123.45")
        else
          # Fallback for tests without Decimal
          "123.45"
        end

      rows = [["Product", decimal_value]]
      columns = ["name", "price"]
      aliases = %{}

      assert {:ok, json} =
               Json.transform(rows, columns, aliases,
                 coerce_types: true,
                 decimal_format: :string
               )

      assert {:ok, [data]} = Jason.decode(json)

      expected_price =
        if Code.ensure_loaded?(Decimal) do
          "123.45"
        else
          "123.45"
        end

      assert %{"name" => "Product", "price" => ^expected_price} = data
    end

    test "handles datetime formatting" do
      dt = ~U[2024-01-01 12:00:00Z]
      rows = [["Event", dt]]
      columns = ["name", "timestamp"]
      aliases = %{}

      assert {:ok, json} =
               Json.transform(rows, columns, aliases,
                 coerce_types: true,
                 date_format: :iso8601
               )

      assert {:ok, [data]} = Jason.decode(json)
      assert %{"name" => "Event", "timestamp" => "2024-01-01T12:00:00Z"} = data
    end

    test "handles date formatting" do
      date = ~D[2024-01-01]
      rows = [["Event", date]]
      columns = ["name", "date"]
      aliases = %{}

      assert {:ok, json} =
               Json.transform(rows, columns, aliases,
                 coerce_types: true,
                 date_format: :iso8601
               )

      assert {:ok, [data]} = Jason.decode(json)
      assert %{"name" => "Event", "date" => "2024-01-01"} = data
    end

    test "handles time formatting" do
      time = ~T[12:30:45]
      rows = [["Event", time]]
      columns = ["name", "time"]
      aliases = %{}

      assert {:ok, json} = Json.transform(rows, columns, aliases, coerce_types: true)
      assert {:ok, [data]} = Jason.decode(json)
      assert %{"name" => "Event", "time" => "12:30:45"} = data
    end

    test "returns error for invalid JSON encoding" do
      # Create data that can't be JSON encoded (like functions)
      rows = [[fn -> :test end]]
      columns = ["func"]
      aliases = %{}

      assert {:error, %Error{type: :transformation_error}} =
               Json.transform(rows, columns, aliases, [])
    end

    test "handles complex nested data" do
      rows = [["User", [1, 2, 3], %{"key" => "value"}]]
      columns = ["name", "numbers", "data"]
      aliases = %{}

      assert {:ok, json} = Json.transform(rows, columns, aliases, [])
      assert {:ok, [data]} = Jason.decode(json)

      assert %{
               "name" => "User",
               "numbers" => [1, 2, 3],
               "data" => %{"key" => "value"}
             } = data
    end
  end

  describe "stream_transform/4" do
    test "streams simple rows to JSON" do
      rows = [
        ["John", 25, "Engineer"],
        ["Jane", 30, "Designer"]
      ]

      columns = ["name", "age", "role"]
      aliases = %{}

      stream = Json.stream_transform(rows, columns, aliases, [])
      json_items = Enum.to_list(stream)

      assert length(json_items) == 2

      # Each item should be valid JSON
      for json_item <- json_items do
        assert {:ok, _data} = Jason.decode(json_item)
      end
    end

    test "streams with metadata on first item" do
      rows = [["John", 25]]
      columns = ["name", "age"]
      aliases = %{}

      stream = Json.stream_transform(rows, columns, aliases, include_meta: true)
      [first_item] = Enum.to_list(stream)

      assert {:ok, response} = Jason.decode(first_item)
      assert %{"data" => [_], "meta" => _meta} = response
    end

    test "streams empty results with metadata" do
      rows = []
      columns = ["name", "age"]
      aliases = %{}

      stream = Json.stream_transform(rows, columns, aliases, include_meta: true)
      [json_item] = Enum.to_list(stream)

      assert {:ok, response} = Jason.decode(json_item)
      assert %{"data" => [], "meta" => _meta} = response
    end

    test "streams without metadata produces individual items" do
      rows = [["John", 25], ["Jane", 30]]
      columns = ["name", "age"]
      aliases = %{}

      stream = Json.stream_transform(rows, columns, aliases, include_meta: false)
      json_items = Enum.to_list(stream)

      assert length(json_items) == 2

      for json_item <- json_items do
        assert {:ok, data} = Jason.decode(json_item)
        # Should be individual objects, not wrapped in data/meta
        assert Map.has_key?(data, "name")
        assert Map.has_key?(data, "age")
      end
    end

    test "streams with null handling" do
      rows = [["John", nil]]
      columns = ["name", "age"]
      aliases = %{}

      stream = Json.stream_transform(rows, columns, aliases, null_handling: :omit)
      [json_item] = Enum.to_list(stream)

      assert {:ok, data} = Jason.decode(json_item)
      assert %{"name" => "John"} = data
      refute Map.has_key?(data, "age")
    end

    test "streams with pretty printing" do
      rows = [["John", 25]]
      columns = ["name", "age"]
      aliases = %{}

      stream = Json.stream_transform(rows, columns, aliases, pretty: true)
      [json_item] = Enum.to_list(stream)

      # Pretty printed JSON should contain formatting
      assert String.contains?(json_item, "\n")
    end

    test "handles streaming errors gracefully" do
      # This should not crash, even with problematic data
      rows = [["valid", "data"], ["invalid", fn -> :bad end]]
      columns = ["col1", "col2"]
      aliases = %{}

      stream = Json.stream_transform(rows, columns, aliases, [])
      # Should be able to collect without crashing
      # The second item might be skipped due to encoding error
      items = Enum.to_list(stream)

      # Should have at least one valid item
      assert length(items) >= 1
    end

    test "works with large datasets efficiently" do
      # Simulate a large dataset
      rows =
        for i <- 1..1000 do
          ["User#{i}", rem(i, 100), "Role#{rem(i, 5)}"]
        end

      columns = ["name", "age", "role"]
      aliases = %{}

      stream = Json.stream_transform(rows, columns, aliases, [])

      # Should be able to process without memory issues
      count = stream |> Enum.take(10) |> length()
      assert count == 10
    end
  end

  describe "option parsing and validation" do
    test "handles invalid options gracefully" do
      rows = [["John", 25]]
      columns = ["name", "age"]
      aliases = %{}

      # Should not crash with unknown options, just ignore them
      assert {:ok, _json} = Json.transform(rows, columns, aliases, unknown_option: true)
    end

    test "handles complex option combinations" do
      rows = [["John", nil, "Engineer"]]
      columns = ["name", "age", "role"]
      aliases = %{"name" => "full_name"}

      assert {:ok, json} =
               Json.transform(rows, columns, aliases,
                 keys: :strings,
                 null_handling: :omit,
                 include_meta: true,
                 pretty: true,
                 coerce_types: false
               )

      assert {:ok, response} = Jason.decode(json)
      assert %{"data" => [data], "meta" => _meta} = response
      assert %{"full_name" => "John", "role" => "Engineer"} = data
      refute Map.has_key?(data, "age")
    end
  end
end
