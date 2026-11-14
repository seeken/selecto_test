defmodule SelectoTestWeb.SelectoViewsUITest do
  use SelectoTestWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "SelectoViews Explorer integration" do
    test "renders the actors domain in the self-contained Explorer", %{conn: conn} do
      {:ok, view, html} = live(conn, "/pagila", on_error: :warn)

      assert html =~ "Pagila Actors"
      assert has_element?(view, "[data-selecto-explorer-host]")
      assert has_element?(view, "[data-selecto-views-explorer]")
      assert has_element?(view, "[data-sc-builder-query]")
      assert has_element?(view, "input[name='field[]'][value='first_name']")
      assert has_element?(view, "input[name='field[]'][value='last_name']")
    end

    test "renders the films domain and database-backed default results", %{conn: conn} do
      {:ok, view, html} = live(conn, "/pagila_films", on_error: :warn)

      assert html =~ "Pagila Films"
      assert has_element?(view, "[data-selecto-views-explorer]")
      assert has_element?(view, ".sc-results table")
      assert has_element?(view, "input[name='field[]'][value='title']")
    end

    test "joined film fields are qualified and execute successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pagila_films", on_error: :warn)

      assert has_element?(
               view,
               "button[phx-click='add-field'][phx-value-field='actor.first_name']"
             )

      refute has_element?(view, "button[phx-click='add-field'][phx-value-field='first_name']")
      refute has_element?(view, "button[phx-click='add-field'][phx-value-field='name']")

      view
      |> element("button[phx-click='add-field'][phx-value-field='actor.first_name']")
      |> render_click()

      html =
        view
        |> element("form[data-sc-builder-query]")
        |> render_submit()

      refute html =~ "The query could not be completed."
      assert html =~ "Actor First Name"
      assert has_element?(view, "[data-sc-count-status]", "counting all matches…")
      assert html =~ "rows on this page"
      refute html =~ "1000 matched rows"
      assert html =~ ~s(class="sc-nested-table")

      # LiveViewTest does not execute the DeferredCount browser hook. Drive its
      # count event with the rendered applied query, token and component target.
      count = html |> Floki.parse_document!() |> Floki.find("h2[data-token]")
      [query] = Floki.attribute(count, "data-query")
      [token] = Floki.attribute(count, "data-token")
      [target] = Floki.attribute(count, "data-target")

      html =
        view
        |> with_target(String.to_integer(target))
        |> render_hook("count", %{"query" => query, "token" => token})

      assert html =~ "1000 matched rows"
      refute has_element?(view, "[data-sc-count-status]")
    end

    test "component-owned events update Explorer draft state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/pagila", on_error: :warn)

      html =
        view
        |> element("button[phx-click='add-filter'][phx-value-field='first_name']")
        |> render_click()

      assert html =~ ~s(name="filter_field[]" value="first_name")
      assert html =~ "1 filter"
    end

    test "serves the packaged SelectoViews stylesheet", %{conn: conn} do
      response = get(conn, "/selecto-views/selecto-views.css")
      assert response.status == 200
      assert get_resp_header(response, "content-type") |> hd() =~ "text/css"
      assert response.resp_body =~ ".sc-page"
    end

    test "the retired Components application is no longer a dependency" do
      assert Application.spec(:selecto_views) != nil
      assert Application.spec(:selecto_components) == nil
    end
  end
end
