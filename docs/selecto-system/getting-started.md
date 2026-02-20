# Getting Started with Selecto

> Status: evolving. APIs in this workspace are under active development.

This guide is aligned to the current `selecto_test` repository.

## Install Dependencies

In this workspace, Selecto packages are path deps:

```elixir
# mix.exs
{:selecto, path: "./vendor/selecto", override: true}
{:selecto_components, path: "./vendor/selecto_components", override: true}
{:selecto_mix, path: "./vendor/selecto_mix", only: [:dev, :test]}
```

Then run:

```bash
mix deps.get
```

## Set Up The App

```bash
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
mix phx.server
```

Try the demo views:

- `http://localhost:4080/pagila`
- `http://localhost:4080/pagila_films`

## Generate A Domain

Current generator task:

```bash
mix selecto.gen.domain MyApp.Catalog.Product
```

Also available (in `selecto_mix`):

- `mix selecto.gen.saved_views`
- `mix selecto.gen.saved_view_configs`
- `mix selecto.gen.filter_sets`
- `mix selecto.components.integrate`

## Use SelectoComponents In A LiveView

Pattern used in this project:

```elixir
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view
  use SelectoComponents.Form

  def mount(_params, _session, socket) do
    selecto = Selecto.configure(MyApp.ProductDomain.domain(), MyApp.Repo)

    views = [
      SelectoComponents.Views.spec(
        :aggregate,
        SelectoComponents.Views.Aggregate,
        "Aggregate View",
        %{drill_down: :detail}
      ),
      SelectoComponents.Views.spec(:detail, SelectoComponents.Views.Detail, "Detail View", %{}),
      SelectoComponents.Views.spec(:graph, SelectoComponents.Views.Graph, "Graph View", %{})
    ]

    state = get_initial_state(views, selecto)
    {:ok, assign(socket, state)}
  end
end
```

Both tuple style and `SelectoComponents.Views.spec/4` are supported; `spec/4` is recommended.

## Add Custom View Systems

`selecto_components` supports pluggable view systems via:

- `SelectoComponents.Views.System`
- `SelectoComponents.Views.spec/4`

Custom view systems must provide callbacks for:

- `initial_state/2`
- `param_to_state/2`
- `view/5`
- `form_component/0`
- `result_component/0`

See `vendor/selecto_components/README.md` section `Implementing A New View System`.

## Saved Views By Type

If your app validates `view_type`, include every enabled view mode in your schema/context validation to allow save/load for those tabs.

## Next

1. [Best Practices](best-practices.md)
2. [API Reference](index.md)
3. [Troubleshooting](troubleshooting.md)
4. [System Overview](system-overview.md)

---

Last updated: 2026-02-20
