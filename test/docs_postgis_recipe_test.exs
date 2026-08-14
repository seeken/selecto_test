if Code.ensure_loaded?(Selecto.Extensions.PostGIS) do
  defmodule DocsPostGISRecipeTest do
    use ExUnit.Case, async: true

    alias Selecto.Config.Overlay
    alias SelectoComponents.Extensions
    alias SelectoComponents.Views.Map.Process, as: MapProcess

    @moduledoc """
    Tests for the PostGIS recipe documented in docs/selecto-system/postgis-recipe.md.
    """

    defmodule RecipeOverlay do
      use Selecto.Config.OverlayDSL,
        extensions: [Selecto.Extensions.PostGIS]

      defmap_view do
        geometry_field("location")
        popup_field("name")
        default_zoom(11)
        center({41.2, -87.6})
        tile_url("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png")
        attribution("&copy; OpenStreetMap contributors")
        cluster(true)
      end
    end

    test "domain extension + overlay adds map defaults and map view" do
      domain =
        base_domain()
        |> Overlay.merge(RecipeOverlay.overlay())

      selecto = SelectoTest.QueryFixture.configure(domain)

      assert selecto.domain.default_map_geometry_field == "location"
      assert selecto.domain.default_map_popup_field == "name"
      assert selecto.domain.default_map_zoom == 11
      assert selecto.domain.default_map_center == {41.2, -87.6}
      assert selecto.domain.default_map_cluster == true

      merged_views = Extensions.merge_views(base_views(), selecto)
      assert Enum.any?(merged_views, fn {id, _, _, _opts} -> id == :map end)
    end

    test "map process generates st_asgeojson selection and SQL" do
      selecto = SelectoTest.QueryFixture.configure(base_domain())

      {view_set, _meta} =
        MapProcess.view(%{}, %{}, Selecto.columns(selecto), [], selecto)

      assert Enum.any?(view_set.selected, fn
               {:field, {:st_asgeojson, field}, "__map_geometry"}
               when field in ["location", :location] ->
                 true

               _ ->
                 false
             end)

      map_query =
        selecto
        |> Selecto.select(view_set.selected)
        |> Selecto.limit(25)

      {sql, _params} = Selecto.to_sql(map_query)

      assert sql =~ ~r/select/i
      assert sql =~ ~r/st_asgeojson/i
      assert sql =~ ~r/from/i
      assert sql =~ ~r/limit/i
    end

    defp base_domain do
      %{
        name: "Places",
        source: %{
          source_table: "places",
          primary_key: :id,
          fields: [:id, :name, :location],
          redact_fields: [],
          columns: %{
            id: %{type: :integer},
            name: %{type: :string},
            location: %{type: :geometry}
          },
          associations: %{}
        },
        schemas: %{},
        joins: %{},
        extensions: [Selecto.Extensions.PostGIS]
      }
    end

    defp base_views do
      [
        {:aggregate, SelectoComponents.Views.Aggregate, "Aggregate View", %{drill_down: :detail}},
        {:detail, SelectoComponents.Views.Detail, "Detail View", %{}},
        {:graph, SelectoComponents.Views.Graph, "Graph View", %{}}
      ]
    end
  end
else
  defmodule DocsPostGISRecipeTest do
    use ExUnit.Case, async: true

    @moduletag skip:
                 "selecto_postgis is not enabled. Use SELECTO_ECOSYSTEM_USE_LOCAL=true or SELECTO_ENABLE_POSTGIS=true"

    test "PostGIS recipe tests require selecto_postgis" do
      assert true
    end
  end
end
