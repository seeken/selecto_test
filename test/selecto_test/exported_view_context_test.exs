defmodule SelectoTest.ExportedViewContextTest do
  use SelectoTest.DataCase, async: true

  alias SelectoTest.ExportedViewContext

  test "lists exported views scoped by context and user" do
    {:ok, first} =
      ExportedViewContext.create_exported_view(
        %{
          name: "Actors dashboard",
          context: "/pagila",
          view_type: "detail",
          public_id: "actors_dashboard",
          cache_ttl_hours: 6,
          snapshot_blob: :erlang.term_to_binary(%{params: %{"view_mode" => "detail"}})
        },
        user_id: "demo_user"
      )

    {:ok, _second} =
      ExportedViewContext.create_exported_view(
        %{
          name: "Films dashboard",
          context: "/pagila_films",
          view_type: "aggregate",
          public_id: "films_dashboard",
          cache_ttl_hours: 3,
          snapshot_blob: :erlang.term_to_binary(%{params: %{"view_mode" => "aggregate"}})
        },
        user_id: "demo_user"
      )

    assert [listed] = ExportedViewContext.list_exported_views("/pagila", user_id: "demo_user")
    assert listed.id == first.id
    assert listed.user_id == "demo_user"
  end
end
