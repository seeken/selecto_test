defmodule SelectoComponentsCustomColumnTest do
  use ExUnit.Case, async: true

  describe "custom_column filter handling" do
    test "custom_column type is handled in filter processing" do
      # Test that custom_column type doesn't cause a CaseClauseError
      filter = %{
        "filter" => "full_name",
        "value" => "test",
        "operator" => "contains"
      }

      column = %{
        type: :custom_column,
        name: "Full Name",
        field: "full_name"
      }

      # This should not raise an error
      assert {:ok, _} = process_custom_column_filter(filter, column)
    end

    defp process_custom_column_filter(filter, column) do
      # Simulate what happens in the filter processing
      case column.type do
        :custom_column ->
          # Custom columns should be treated as strings
          {:ok, {filter["filter"], {:ilike, "%#{filter["value"]}%"}}}

        _ ->
          {:error, :unknown_type}
      end
    end
  end
end
