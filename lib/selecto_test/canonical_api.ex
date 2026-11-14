defmodule SelectoTest.CanonicalApi do
  @moduledoc """
  The canonical Selecto API for the Pagila Explorer domains, served by
  `selecto_api` under `/api/selecto/canonical`.

  Each domain publishes `remote_query.v1` (manifest, OpenAPI, domain document
  and `POST <domain>/query`), its `selecto.explorer-metadata` document at
  `<domain>/explorer`, and `remote_query.explorer.v1` (`<domain>/explorer-features`
  and `POST <domain>/explorer-query`). `GET /api/selecto/canonical/catalog` lists
  the domains, so frontends with the `auto` transport select the canonical API.

  `SelectoApi.CanonicalHost`, `SelectoApi.ExplorerPublication`,
  `SelectoApi.EngineHandler` and `SelectoApi.Explorer` validate and run every
  request; this module only builds the hosts and routes requests to them. The
  queries run through the same `Selecto.configure/2` domains and repo as the
  LiveView Explorer at `/pagila` and `/pagila_films`.

  This demo app has no authentication, so the publication identity is derived
  from the domain fingerprint and grants no row authority.
  """

  alias SelectoApi.{
    CanonicalHost,
    CanonicalJSON,
    EngineHandler,
    Explorer,
    ExplorerPublication
  }

  @base "/api/selecto/canonical"
  @catalog @base <> "/catalog"
  @max_limit 500
  @limits %{
    max_limit: @max_limit,
    max_offset: 100_000,
    max_groups: 1_000,
    max_export_rows: 10_000,
    max_count_rows: 100_000
  }

  @doc "The canonical API base path."
  def base_path, do: @base

  @doc "The domain catalog path."
  def catalog_path, do: @catalog

  @doc "The published domains: `{id, label, domain}`."
  def domains do
    [
      {"actors", "Pagila actors", SelectoTest.PagilaDomain.actors_domain()},
      {"films", "Pagila films", SelectoTest.PagilaDomainFilms.domain()}
    ]
  end

  @doc """
  Dispatches one request. `body` is the decoded JSON body (or `nil`), `headers`
  a map of lower-case request headers. Returns `%{status, headers, body}`.
  """
  def request(method, path, body, headers \\ %{}) do
    entries = hosts()

    cond do
      method == "GET" and path == @catalog ->
        encoded(200, ExplorerPublication.catalog(Enum.map(entries, &elem(&1, 1))))

      entry = Enum.find(entries, fn {_id, host, _domain} -> owns?(host, path) end) ->
        {_id, host, domain} = entry
        source = fn -> Selecto.configure(domain, SelectoTest.Repo) end
        options = ExplorerPublication.detail_options() ++ [max_limit: @max_limit]

        CanonicalHost.request(
          host,
          %{method: method, path: path, body: body, headers: headers},
          %{
            query: EngineHandler.handler(source, options),
            explorer_query: Explorer.handler(source)
          }
        )

      true ->
        CanonicalHost.error_response(404, "route_not_found", "Route is absent.")
    end
  end

  defp owns?(%CanonicalHost{base_path: base}, path),
    do: path == base or String.starts_with?(path, base <> "/")

  # The hosts depend only on the domain modules, so build them once.
  defp hosts do
    with nil <- :persistent_term.get({__MODULE__, :hosts}, nil) do
      hosts =
        Enum.map(domains(), fn {id, label, domain} -> {id, host(id, label, domain), domain} end)

      :persistent_term.put({__MODULE__, :hosts}, hosts)
      hosts
    end
  end

  defp host(id, label, domain) do
    contract = contract(domain)

    {:ok, host, _diagnostics} =
      CanonicalHost.new(contract, path: "#{@base}/#{id}", profiles: ["remote_query.v1"])

    publication = "selecto-test-#{id}:" <> host.manifest["domain"]["fingerprint"]

    {:ok, host} =
      ExplorerPublication.attach(host,
        id: id,
        publication: publication,
        label: label,
        fields: explorer_fields(host),
        max_limit: @max_limit,
        catalog_path: @catalog
      )

    {:ok, host} =
      Explorer.attach(host, %{
        id: id,
        label: label,
        publication: publication,
        default_limit: 25,
        # The development seeds hold more actors than max_count_rows, so an
        # exact count would refuse; paging reports has_more instead.
        count_exact: false,
        limits: @limits,
        collection_limit: 100,
        timezones: "iana"
      })

    host
  end

  # Canonical hosting needs a complete domain identity. The Pagila domains are
  # schema 1 maps without one, so publish the canonical JSON digest of the
  # JSON form as the fingerprint, as the Collecto builders do.
  defp contract(domain) do
    contract =
      domain
      |> SelectoUpdato.DomainContract.json_safe()
      |> Map.put("schema_version", 1)
      |> Map.put("domain_version", "1.0.0")

    digest = :crypto.hash(:sha256, CanonicalJSON.encode!(contract))
    Map.put(contract, "domain_fingerprint", "sha256:" <> Base.encode16(digest, case: :lower))
  end

  # The explorer metadata lists root fields the governed handler can filter
  # and sort; columns the domain marks hidden, internal, unfilterable or
  # unsortable stay out of it.
  defp explorer_fields(%CanonicalHost{domain: domain, openapi: openapi}) do
    columns = get_in(domain, ["source", "columns"]) || %{}

    openapi
    |> get_in(["x-selecto", "fields"])
    |> Enum.map(& &1["path"])
    |> Enum.reject(&String.contains?(&1, "."))
    |> Enum.filter(fn field ->
      definition = Map.get(columns, field, %{})

      definition["hidden"] != true and definition["internal"] != true and
        Enum.all?(~w(filterable sortable), &(definition[&1] != false))
    end)
  end

  defp encoded(status, body) do
    %{
      status: status,
      headers: %{"content-type" => "application/json; charset=utf-8"},
      body: CanonicalJSON.encode!(body)
    }
  end
end
