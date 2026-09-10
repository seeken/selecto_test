# Selecto PostGIS Full Recipe

> Status: tested in this workspace with `SELECTO_ECOSYSTEM_USE_LOCAL=true`.

This guide shows a full end-to-end setup for Selecto + PostGIS, including a
domain, overlay defaults, and a reproducible test.

## 1) Enable `selecto_db_postgresql_postgis`

In this repo, `mix.exs` includes PostGIS support when either of these is true:

- `SELECTO_ECOSYSTEM_USE_LOCAL=true` (uses vendored Selecto ecosystem packages)
- `SELECTO_ENABLE_POSTGIS=true` (enables the Hex `selecto_db_postgresql_postgis` dep)

Install deps with your chosen mode enabled:

```bash
SELECTO_ECOSYSTEM_USE_LOCAL=true mix deps.get
```

## 2) Enable PostGIS in PostgreSQL

Add a migration:

```elixir
defmodule MyApp.Repo.Migrations.EnablePostgis do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS postgis")

    create table(:places) do
      add :name, :string, null: false
      add :location, :geometry, null: false
      timestamps(type: :utc_datetime)
    end

    execute("CREATE INDEX places_location_gix ON places USING GIST (location)")
  end

  def down do
    drop table(:places)
  end
end
```

## 3) Ecto schema with geometry type

```elixir
defmodule MyApp.Place do
  use Ecto.Schema

  schema "places" do
    field :name, :string
    field :location, Geo.PostGIS.Geometry
    timestamps(type: :utc_datetime)
  end
end
```

## 4) Selecto domain + PostGIS extension

```elixir
domain = %{
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
```

## 5) Optional overlay map defaults

```elixir
defmodule MyApp.Overlays.PlacesOverlay do
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
```

Merge the overlay before `Selecto.configure/2`:

```elixir
merged_domain =
  domain
  |> Selecto.Config.Overlay.merge(MyApp.Overlays.PlacesOverlay.overlay())

selecto = Selecto.configure(merged_domain, MyApp.Repo)
```

## 6) Register views (map view is extension-driven)

Keep your base views and merge extension views:

```elixir
base_views = [
  SelectoComponents.Views.spec(
    :aggregate,
    SelectoComponents.Views.Aggregate,
    "Aggregate View",
    %{drill_down: :detail}
  ),
  SelectoComponents.Views.spec(:detail, SelectoComponents.Views.Detail, "Detail View", %{}),
  SelectoComponents.Views.spec(:graph, SelectoComponents.Views.Graph, "Graph View", %{})
]

views = SelectoComponents.Extensions.merge_views(base_views, selecto)
```

When spatial columns are present, `views` includes `{:map, SelectoComponents.Views.Map, ...}`.

## 7) SQL probe for map geometry projection

`SelectoComponents.Views.Map.Process` builds map selections using
`st_asgeojson(...)`.

```elixir
{view_set, _meta} =
  SelectoComponents.Views.Map.Process.view(%{}, %{}, Selecto.columns(selecto), [], selecto)

query =
  selecto
  |> Selecto.select(view_set.selected)
  |> Selecto.limit(25)

{sql, _params} = Selecto.to_sql(query)
# sql contains st_asgeojson and limit
```

## 8) Run the recipe test in this repo

Recipe coverage lives in:

- `test/docs_postgis_recipe_test.exs`

Run it with local ecosystem deps enabled:

```bash
SELECTO_ECOSYSTEM_USE_LOCAL=true mix test test/docs_postgis_recipe_test.exs
```

If PostGIS dep is not enabled, the test module is skipped with a clear reason.

---

Last updated: 2026-03-02
