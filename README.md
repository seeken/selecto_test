# Selecto Test Project

`selecto_test` is the PostgreSQL-backed Phoenix integration app for `selecto`
and the self-contained `selecto_views` Explorer.

## Main routes

- `/` and `/pagila` — actor exploration
- `/pagila_films` — film exploration
- `/pagila/film/:film_id` — focused film page
- `/docs/selecto-system/*` — local integration documentation
- `/api/selecto/canonical/*` — the canonical Selecto API for the same domains
- `/dev/dashboard` — Phoenix LiveDashboard in development

## Setup

```bash
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix deps.get
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix ecto.setup
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix phx.server
```

The default development port is `4117`; override it with `PORT` and use
`PHX_DEV_HOSTNAME` when the host name must differ from `localhost`.

## Explorer integration

`SelectoTestWeb.PagilaLive` configures a domain and repository, then passes the
result directly to `SelectoViews.Explorer`. The Explorer owns draft/applied
query state, detail/aggregate/graph presentation, execution, pagination, and
drilldown. The host serves the package stylesheet at
`/selecto-views/selecto-views.css`.

Saved-view, exported-view, and filter-set database contexts remain in this
test application for persistence experiments, but they are not wired into the
current Explorer because `selecto_views` does not yet publish those host
adapter contracts.

## Canonical API

`SelectoTest.CanonicalApi` publishes the two Explorer domains through
`selecto_api` under `/api/selecto/canonical`, the mount the Collecto builders
use:

- `GET /api/selecto/canonical/catalog` — the `selecto.domain-catalog` listing
  `actors` and `films`; frontends with the `auto` transport
  (`@selecto/explorer-client`) select the canonical API when it answers
- `GET /api/selecto/canonical/<id>` — the `remote_query.v1` manifest, with the
  domain document, OpenAPI and `POST <id>/query`
- `GET /api/selecto/canonical/<id>/explorer` — `selecto.explorer-metadata`
- `GET <id>/explorer-features` and `POST <id>/explorer-query` —
  `remote_query.explorer.v1` (Detail, Aggregate, Graph, rollup, grid, group
  formats, buckets and exports over the same governed engine path)

Queries run through the same `Selecto.configure/2` domains and repo as the
LiveView Explorer. The domains are schema 1 maps without an identity, so each
publishes the canonical JSON digest of its JSON form as its fingerprint. Columns
the domain marks unfilterable or unsortable (for example film `description`)
are left out of the explorer metadata. Exact counts are not offered because the
development seeds hold more actors than `max_count_rows`; paging reports
`has_more` instead. The app has no authentication, so the publication identity
grants no row authority.

## Verification

```bash
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix format --check-formatted
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix compile --force --warnings-as-errors
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix test
```

Run `mix test.setup` before `mix test`. The tests require the configured
PostgreSQL test database (point it elsewhere, for example at a RAM-backed
instance, with `SELECTO_TEST_PG_URL` or the `SELECTO_TEST_PG_*` variables) and
include database-backed LiveView coverage for both Explorer routes and
controller coverage for the canonical API.
