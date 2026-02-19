defmodule SelectoComponentsNestedTableScalarSubselectTest do
  use ExUnit.Case, async: true

  alias SelectoComponents.Components.NestedTable

  describe "parse_subselect_data/2" do
    test "normalizes scalar lists using tuple column config" do
      config = %{columns: [{"c1", "posts.title", %{}}]}

      parsed = NestedTable.parse_subselect_data(["First", "Second"], config)

      assert parsed == [%{"title" => "First"}, %{"title" => "Second"}]
      assert NestedTable.get_data_keys(parsed) == ["title"]
    end

    test "normalizes scalar JSON arrays using map column config" do
      config = %{columns: [%{field: "posts[title]"}]}

      parsed = NestedTable.parse_subselect_data(~s(["A","B"]), config)

      assert parsed == [%{"title" => "A"}, %{"title" => "B"}]
      assert NestedTable.get_data_keys(parsed) == ["title"]
    end

    test "preserves map-shaped subselect rows" do
      data = [%{"title" => "A"}, %{"title" => "B"}]

      assert NestedTable.parse_subselect_data(data, %{columns: []}) == data
    end

    test "uses value fallback key when no column metadata exists" do
      parsed = NestedTable.parse_subselect_data([1, 2], %{})

      assert parsed == [%{"value" => 1}, %{"value" => 2}]
      assert NestedTable.get_data_keys(parsed) == ["value"]
    end
  end
end
