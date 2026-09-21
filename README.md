# Selecto Test Project

`selecto_test` is the PostgreSQL-backed Phoenix integration app for `selecto`
and the self-contained `selecto_views` Explorer.

## Main routes

- `/` and `/pagila` — actor exploration
- `/pagila_films` — film exploration
- `/pagila/film/:film_id` — focused film page
- `/docs/selecto-system/*` — local integration documentation
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

## Verification

```bash
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix format --check-formatted
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix compile --force --warnings-as-errors
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix test
```

The tests require the configured PostgreSQL test database and include
database-backed LiveView coverage for both Explorer routes.
