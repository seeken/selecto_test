defmodule SelectoTest.FilterSetsTest do
  use SelectoTest.DataCase, async: true

  alias SelectoTest.FilterSets
  alias SelectoTest.FilterSets.FilterSet

  describe "filter sets" do
    test "create_filter_set/1 creates a filter set" do
      attrs = %{
        name: "Test Filter",
        domain: "test_domain",
        filters: %{"field" => "value"},
        user_id: "user123"
      }

      assert {:ok, %FilterSet{} = filter_set} = FilterSets.create_filter_set(attrs)
      assert filter_set.name == "Test Filter"
      assert filter_set.domain == "test_domain"
    end

    # Add more tests as needed
  end
end
