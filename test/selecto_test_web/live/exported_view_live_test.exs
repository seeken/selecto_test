defmodule SelectoTestWeb.ExportedViewLiveTest do
  use SelectoTestWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias SelectoComponents.ExportedViews.Token
  alias SelectoTest.ExportedViewContext

  test "serves a signed exported iframe view", %{conn: conn} do
    {:ok, view} =
      ExportedViewContext.create_exported_view(
        %{
          name: "Actors Snapshot",
          context: "/pagila",
          view_type: "detail",
          public_id: "actors_snapshot",
          cache_ttl_hours: 3,
          snapshot_blob: :erlang.term_to_binary(%{params: %{"view_mode" => "detail"}}),
          cache_blob:
            :erlang.term_to_binary(%{
              selecto: %{},
              views: [],
              query_results: nil,
              view_meta: %{},
              applied_view: nil,
              executed: false,
              execution_error: nil,
              last_query_info: %{},
              params: %{"view_mode" => "detail"},
              used_params: %{"view_mode" => "detail"}
            }),
          cache_generated_at: DateTime.utc_now() |> DateTime.truncate(:second),
          cache_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          access_count: 0
        },
        user_id: "demo_user"
      )

    token = Token.sign(view, endpoint: SelectoTestWeb.Endpoint)

    {:ok, _live, html} =
      live(conn, "/selecto/exported/actors_snapshot?sig=#{token}", on_error: :warn)

    assert html =~ "Selecto Exported View"
    assert html =~ "Actors Snapshot"
  end
end
