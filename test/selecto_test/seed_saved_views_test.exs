defmodule SelectoTest.SeedSavedViewsTest do
  use SelectoTest.DataCase, async: true

  alias SelectoTest.{SavedView, Seed}

  test "saved view seeds cover films and actors and can be inserted" do
    saved_views = Seed.saved_views()

    assert length(saved_views) >= 24

    film_views = Enum.filter(saved_views, &(&1.context == "/pagila_films"))
    actor_views = Enum.filter(saved_views, &(&1.context == "/pagila"))

    assert length(film_views) >= 12
    assert length(actor_views) >= 12

    names_by_context = Enum.map(saved_views, &{&1.context, &1.name})
    assert Enum.uniq(names_by_context) == names_by_context

    assert Enum.any?(film_views, &(&1.name == "Premium Long Features"))
    assert Enum.any?(actor_views, &(&1.name == "Actor Filmography Snapshot"))
    assert Enum.any?(actor_views, &(&1.name == "Replacement Cost Exposure"))

    Enum.each(saved_views, fn attrs ->
      %SavedView{}
      |> SavedView.changeset(attrs)
      |> Repo.insert!()
    end)

    assert Repo.aggregate(SavedView, :count) == length(saved_views)
  end
end
