defmodule Selecto.Output.Transformers.CSVTest do
  use ExUnit.Case, async: true

  alias Selecto.Output.Transformers.CSV

  # Sample test data
  @sample_rows [
    ["Alice", 25, true, ~D[2023-01-01]],
    ["Bob", 30, false, ~D[2023-02-15]],
    ["Charlie", nil, true, nil]
  ]

  @sample_columns [
    %{name: "name", type: :string},
    %{name: "age", type: :integer},
    %{name: "active", type: :boolean},
    %{name: "created_date", type: :date}
  ]

  @sample_aliases ["name", "age", "active", "created_date"]

  describe "transform/4" do
    test "transforms basic data with default options" do
      rows = [["Alice", 25], ["Bob", 30]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases)

      expected = "name,age\nAlice,25\nBob,30\n"
      assert csv == expected
    end

    test "handles empty result set" do
      {:ok, csv} = CSV.transform([], @sample_columns, @sample_aliases)

      expected = "name,age,active,created_date\n"
      assert csv == expected
    end

    test "handles empty result set without headers" do
      {:ok, csv} = CSV.transform([], @sample_columns, @sample_aliases, headers: false)

      expected = ""
      assert csv == expected
    end

    test "excludes headers when headers: false" do
      rows = [["Alice", 25]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, headers: false)

      expected = "Alice,25\n"
      assert csv == expected
    end

    test "handles null values with default representation" do
      rows = [["Alice", nil], [nil, 30]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases)

      expected = "name,age\nAlice,\n,30\n"
      assert csv == expected
    end

    test "handles null values with custom representation" do
      rows = [["Alice", nil], [nil, 30]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, null_value: "N/A")

      expected = "name,age\nAlice,N/A\nN/A,30\n"
      assert csv == expected
    end
  end

  describe "field quoting and escaping" do
    test "quotes fields containing commas" do
      rows = [["Smith, John", 25]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases)

      expected = "name,age\n\"Smith, John\",25\n"
      assert csv == expected
    end

    test "quotes fields containing quote characters" do
      rows = [["Say \"Hello\"", 25]]
      columns = [%{name: "message", type: :string}, %{name: "age", type: :integer}]
      aliases = ["message", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases)

      expected = "message,age\n\"Say \"\"Hello\"\"\",25\n"
      assert csv == expected
    end

    test "quotes fields containing newlines" do
      rows = [["Line 1\nLine 2", 25]]
      columns = [%{name: "text", type: :string}, %{name: "age", type: :integer}]
      aliases = ["text", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases)

      expected = "text,age\n\"Line 1\nLine 2\",25\n"
      assert csv == expected
    end

    test "quotes fields containing carriage returns" do
      rows = [["Line 1\r\nLine 2", 25]]
      columns = [%{name: "text", type: :string}, %{name: "age", type: :integer}]
      aliases = ["text", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases)

      expected = "text,age\n\"Line 1\r\nLine 2\",25\n"
      assert csv == expected
    end

    test "forces quotes on all fields when force_quotes: true" do
      rows = [["Alice", 25]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, force_quotes: true)

      expected = "\"name\",\"age\"\n\"Alice\",\"25\"\n"
      assert csv == expected
    end
  end

  describe "delimiter customization" do
    test "uses semicolon delimiter" do
      rows = [["Alice", 25]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, delimiter: ";")

      expected = "name;age\nAlice;25\n"
      assert csv == expected
    end

    test "uses tab delimiter" do
      rows = [["Alice", 25]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, delimiter: "\t")

      expected = "name\tage\nAlice\t25\n"
      assert csv == expected
    end

    test "quotes fields containing custom delimiter" do
      rows = [["Alice;Bob", 25]]
      columns = [%{name: "names", type: :string}, %{name: "age", type: :integer}]
      aliases = ["names", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, delimiter: ";")

      expected = "names;age\n\"Alice;Bob\";25\n"
      assert csv == expected
    end
  end

  describe "quote character customization" do
    test "uses custom quote character" do
      rows = [["Smith, John", 25]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, quote_char: "'")

      expected = "name,age\n'Smith, John',25\n"
      assert csv == expected
    end

    test "escapes custom quote character within fields" do
      rows = [["It's working", 25]]
      columns = [%{name: "message", type: :string}, %{name: "age", type: :integer}]
      aliases = ["message", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, quote_char: "'")

      expected = "message,age\n'It''s working',25\n"
      assert csv == expected
    end
  end

  describe "line ending customization" do
    test "uses Windows line endings" do
      rows = [["Alice", 25]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, line_ending: "\r\n")

      expected = "name,age\r\nAlice,25\r\n"
      assert csv == expected
    end

    test "uses custom line ending" do
      rows = [["Alice", 25]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, line_ending: "||")

      expected = "name,age||Alice,25||"
      assert csv == expected
    end
  end

  describe "data type handling" do
    test "handles various data types correctly" do
      {:ok, csv} = CSV.transform(@sample_rows, @sample_columns, @sample_aliases)

      lines = String.split(csv, "\n", trim: true)
      assert Enum.at(lines, 0) == "name,age,active,created_date"
      assert Enum.at(lines, 1) == "Alice,25,true,2023-01-01"
      assert Enum.at(lines, 2) == "Bob,30,false,2023-02-15"
      assert Enum.at(lines, 3) == "Charlie,,true,"
    end

    test "handles decimal values" do
      rows = [["Product A", Decimal.new("19.99")]]
      columns = [%{name: "name", type: :string}, %{name: "price", type: :decimal}]
      aliases = ["name", "price"]

      {:ok, csv} = CSV.transform(rows, columns, aliases)

      expected = "name,price\nProduct A,19.99\n"
      assert csv == expected
    end

    test "handles datetime values" do
      dt = ~U[2023-01-01 12:30:00Z]
      rows = [["Event", dt]]
      columns = [%{name: "name", type: :string}, %{name: "timestamp", type: :utc_datetime}]
      aliases = ["name", "timestamp"]

      {:ok, csv} = CSV.transform(rows, columns, aliases)

      expected = "name,timestamp\nEvent,2023-01-01 12:30:00Z\n"
      assert csv == expected
    end
  end

  describe "stream_transform/4" do
    test "produces CSV stream with headers" do
      rows = [["Alice", 25], ["Bob", 30]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, stream} = CSV.stream_transform(rows, columns, aliases)
      result = Enum.join(stream, "")

      expected = "name,age\nAlice,25\nBob,30\n"
      assert result == expected
    end

    test "produces CSV stream without headers" do
      rows = [["Alice", 25], ["Bob", 30]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, stream} = CSV.stream_transform(rows, columns, aliases, headers: false)
      result = Enum.join(stream, "")

      expected = "Alice,25\nBob,30\n"
      assert result == expected
    end

    test "handles streaming with custom options" do
      rows = [["Smith, John", 25]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, stream} =
        CSV.stream_transform(rows, columns, aliases, delimiter: ";", quote_char: "'")

      result = Enum.join(stream, "")

      expected = "name;age\n'Smith, John';25\n"
      assert result == expected
    end

    test "handles empty stream" do
      {:ok, stream} = CSV.stream_transform([], @sample_columns, @sample_aliases)
      result = Enum.join(stream, "")

      expected = "name,age,active,created_date\n"
      assert result == expected
    end

    test "handles large dataset efficiently" do
      # Generate large dataset
      large_rows = for i <- 1..1000, do: ["User #{i}", i]
      columns = [%{name: "name", type: :string}, %{name: "id", type: :integer}]
      aliases = ["name", "id"]

      {:ok, stream} = CSV.stream_transform(large_rows, columns, aliases)

      # Stream should be lazy - count lines without fully materializing
      line_count = stream |> Stream.take(10) |> Enum.count()
      assert line_count == 10
    end

    test "handles streaming with type coercion errors gracefully" do
      # Test with problematic data that might cause coercion issues
      rows = [["Alice", %{complex: "data"}], ["Bob", 30]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:ok, stream} = CSV.stream_transform(rows, columns, aliases)
      result = Enum.join(stream, "")

      lines = String.split(result, "\n", trim: true)
      assert Enum.at(lines, 0) == "name,age"
      # Should handle the problematic row by converting to string representation
      assert String.contains?(Enum.at(lines, 1), "Alice")
      assert Enum.at(lines, 2) == "Bob,30"
    end
  end

  describe "option validation" do
    test "validates headers option" do
      {:error, error} = CSV.transform([], @sample_columns, @sample_aliases, headers: "invalid")

      assert %Selecto.Error{type: :transformation_error} = error
      assert error.message =~ "headers option must be a boolean"
    end

    test "validates delimiter option" do
      {:error, error} = CSV.transform([], @sample_columns, @sample_aliases, delimiter: ",,")

      assert %Selecto.Error{type: :transformation_error} = error
      assert error.message =~ "delimiter must be a single character string"
    end

    test "validates quote_char option" do
      {:error, error} = CSV.transform([], @sample_columns, @sample_aliases, quote_char: "''")

      assert %Selecto.Error{type: :transformation_error} = error
      assert error.message =~ "quote_char must be a single character string"
    end

    test "validates null_value option" do
      {:error, error} = CSV.transform([], @sample_columns, @sample_aliases, null_value: 123)

      assert %Selecto.Error{type: :transformation_error} = error
      assert error.message =~ "null_value must be a string"
    end

    test "validates force_quotes option" do
      {:error, error} = CSV.transform([], @sample_columns, @sample_aliases, force_quotes: "yes")

      assert %Selecto.Error{type: :transformation_error} = error
      assert error.message =~ "force_quotes option must be a boolean"
    end

    test "validates line_ending option" do
      {:error, error} = CSV.transform([], @sample_columns, @sample_aliases, line_ending: 123)

      assert %Selecto.Error{type: :transformation_error} = error
      assert error.message =~ "line_ending must be a string"
    end

    test "validates delimiter and quote_char are different" do
      {:error, error} =
        CSV.transform([], @sample_columns, @sample_aliases, delimiter: "\"", quote_char: "\"")

      assert %Selecto.Error{type: :transformation_error} = error
      assert error.message =~ "delimiter and quote_char cannot be the same"
    end
  end

  describe "error handling" do
    test "handles mismatched row and column lengths" do
      # Missing age value
      rows = [["Alice"]]
      columns = [%{name: "name", type: :string}, %{name: "age", type: :integer}]
      aliases = ["name", "age"]

      {:error, error} = CSV.transform(rows, columns, aliases)

      assert %Selecto.Error{type: :transformation_error} = error
      assert error.message =~ "Row coercion failed"
    end

    test "provides context in error messages" do
      {:error, error} = CSV.transform([], @sample_columns, @sample_aliases, delimiter: "invalid")

      assert %Selecto.Error{type: :transformation_error} = error
      assert is_map(error.details)
      assert Map.has_key?(error.details, :columns)
    end
  end

  describe "complex scenarios" do
    test "handles mixed special characters" do
      rows = [["Line 1,\nwith \"quotes\"\r\nand, commas", 42]]
      columns = [%{name: "text", type: :string}, %{name: "number", type: :integer}]
      aliases = ["text", "number"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, [])

      # The CSV should contain the properly formatted output
      # Don't split by lines since the field contains embedded newlines
      assert String.starts_with?(csv, "text,number\n")
      assert String.contains?(csv, "\"Line 1,\nwith \"\"quotes\"\"\r\nand, commas\",42")
      # Escaped quotes
      assert String.contains?(csv, "\"\"quotes\"\"")
    end

    test "handles all null row" do
      rows = [[nil, nil, nil]]

      columns = [
        %{name: "a", type: :string},
        %{name: "b", type: :integer},
        %{name: "c", type: :boolean}
      ]

      aliases = ["a", "b", "c"]

      {:ok, csv} = CSV.transform(rows, columns, aliases, null_value: "NULL")

      expected = "a,b,c\nNULL,NULL,NULL\n"
      assert csv == expected
    end
  end
end
