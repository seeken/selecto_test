defmodule SelectoTestWeb.PagilaViewApplyTest do
  use SelectoTestWeb.ConnCase

  test "PagilaLive view-apply pushes a patch for a valid aggregate submit" do
    socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, live_action: :films}}

    {:ok, mounted_socket} = SelectoTestWeb.PagilaLive.mount(%{}, %{}, socket)

    params = %{
      "form_state_revision" => to_string(mounted_socket.assigns.form_state_revision),
      "view_mode" => "aggregate",
      "group_by" => %{
        "k0" => %{
          "field" => "release_year",
          "index" => "0",
          "uuid" => "g1",
          "alias" => "Release Year"
        }
      },
      "aggregate" => %{
        "k0" => %{
          "field" => "id",
          "function" => "count",
          "index" => "0",
          "uuid" => "a1",
          "alias" => "Film ID Count"
        }
      },
      "aggregate_per_page" => "100",
      "aggregate_grid" => "false",
      "aggregate_grid_colorize" => "false",
      "aggregate_grid_color_scale" => "linear"
    }

    {:noreply, updated_socket} =
      SelectoTestWeb.PagilaLive.handle_event("view-apply", params, mounted_socket)

    assert {:live, :patch, %{to: to}} = updated_socket.redirected
    assert to =~ "/pagila_films?"
    assert to =~ "view_mode=aggregate"
    assert to =~ "group_by"
    assert to =~ "aggregate"
  end
end
