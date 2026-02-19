defmodule SelectoComponentsAutoPivotUnitTest do
  use ExUnit.Case

  # Test the helper functions directly 
  # This avoids needing full Selecto query execution

  describe "auto pivot detection logic" do
    test "detects when columns are missing from source table" do
      # Create mock selecto with domain
      _selecto = %{
        domain: %{
          source: %{
            columns: %{
              actor_id: %{},
              first_name: %{},
              last_name: %{}
            }
          }
        }
      }

      # Import the private functions for testing
      # We'll test the logic separately
      source_columns = [:actor_id, :first_name, :last_name]

      # Test with column that exists
      assert column_exists?("first_name", source_columns) == true
      assert column_exists?(:first_name, source_columns) == true

      # Test with column that doesn't exist  
      assert column_exists?("title", source_columns) == false
      assert column_exists?(:title, source_columns) == false
    end

    test "finds correct pivot target based on columns" do
      schemas = %{
        films: %{
          columns: %{
            film_id: %{},
            title: %{},
            release_year: %{},
            rating: %{}
          }
        },
        actors: %{
          columns: %{
            actor_id: %{},
            first_name: %{},
            last_name: %{}
          }
        }
      }

      # Should find films when looking for film columns
      film_columns = ["title", "release_year"]
      target = find_target_with_columns(film_columns, schemas)
      assert target == :films

      # Should find actors when looking for actor columns
      actor_columns = ["first_name", "last_name"]
      target = find_target_with_columns(actor_columns, schemas)
      assert target == :actors

      # Should return nil when columns don't match any schema
      unknown_columns = ["unknown_col1", "unknown_col2"]
      target = find_target_with_columns(unknown_columns, schemas)
      assert target == nil
    end

    test "extracts columns from aggregate view config" do
      view_config = %{
        "view_mode" => "aggregate",
        "group_by" => %{
          "1" => %{"field" => "rental_date", "index" => "1"},
          "2" => %{"field" => "customer_id", "index" => "2"}
        },
        "aggregate" => %{
          "1" => %{"field" => "amount", "format" => "sum", "index" => "1"}
        }
      }

      columns = extract_columns_from_view(view_config)
      assert "rental_date" in columns
      assert "customer_id" in columns
      assert "amount" in columns
    end

    test "extracts columns from detail view config" do
      view_config = %{
        "view_mode" => "detail",
        "selected" => ["title", "release_year", "rating"]
      }

      columns = extract_columns_from_view(view_config)
      assert columns == ["title", "release_year", "rating"]
    end
  end

  # Helper functions that mirror the logic in router.ex
  defp column_exists?(column_name, source_columns) do
    col_atom = if is_binary(column_name), do: String.to_atom(column_name), else: column_name
    col_string = if is_atom(column_name), do: Atom.to_string(column_name), else: column_name

    Enum.any?(source_columns, fn source_col ->
      source_col == col_atom or source_col == col_string or
        Atom.to_string(source_col) == col_string
    end)
  end

  defp find_target_with_columns(selected_columns, schemas) do
    Enum.find_value(schemas, fn {schema_name, schema_config} ->
      schema_columns = Map.keys(schema_config.columns || %{})

      if has_all_columns?(selected_columns, schema_columns) do
        schema_name
      else
        nil
      end
    end)
  end

  defp has_all_columns?(selected_columns, schema_columns) do
    Enum.all?(selected_columns, fn col ->
      col_atom = if is_binary(col), do: String.to_atom(col), else: col
      col_string = if is_atom(col), do: Atom.to_string(col), else: col

      Enum.any?(schema_columns, fn schema_col ->
        schema_col == col_atom or schema_col == col_string or
          Atom.to_string(schema_col) == col_string
      end)
    end)
  end

  defp extract_columns_from_view(view_config) do
    view_mode = view_config["view_mode"] || view_config[:view_mode]

    case view_mode do
      "aggregate" ->
        group_by_cols =
          Map.get(view_config, "group_by", %{})
          |> Map.values()
          |> Enum.map(fn item -> item["field"] end)

        aggregate_cols =
          Map.get(view_config, "aggregate", %{})
          |> Map.values()
          |> Enum.map(fn item -> item["field"] end)

        group_by_cols ++ aggregate_cols

      "detail" ->
        Map.get(view_config, "selected", Map.get(view_config, :selected, []))

      _ ->
        []
    end
  end
end
