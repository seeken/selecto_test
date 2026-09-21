# Getting Started with SelectoViews

Configure Selecto in the host LiveView and render the self-contained Explorer:

```elixir
def mount(params, _session, socket) do
  selecto = Selecto.configure(MyApp.CatalogDomain.domain(), MyApp.Repo)
  {:ok, assign(socket, selecto: selecto, params: params)}
end
```

```heex
<.live_component
  module={SelectoViews.Explorer}
  id="catalog-explorer"
  selecto={@selecto}
  params={@params}
  options={[
    title: "Catalog",
    stylesheet_href: "/selecto-views/selecto-views.css"
  ]}
/>
```

Serve `selecto_views` static assets from the endpoint:

```elixir
plug Plug.Static,
  at: "/selecto-views",
  from: :selecto_views,
  gzip: false,
  only: ~w(selecto-views.css)
```

The Explorer owns its event lifecycle. The host remains responsible for the
domain, repository, adapter configuration, authorization, and deployment.
