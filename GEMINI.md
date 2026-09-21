# Project overview

This Phoenix LiveView application is the PostgreSQL-backed integration host for
the sibling `selecto`, `selecto_db_postgresql`, `selecto_views`, and
`selecto_mix` repositories.

The primary UI is `SelectoViews.Explorer`. Host LiveViews configure `%Selecto{}`
values and pass them to the component; they do not import Explorer callbacks.
The package stylesheet is served by `SelectoTestWeb.Endpoint` at
`/selecto-views/selecto-views.css`.

Use the sibling repositories with:

```bash
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix deps.get
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix ecto.setup
SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix phx.server
```

Run `SELECTO_ECOSYSTEM_USE_LOCAL=1 mise exec -- mix test` for the PostgreSQL and
LiveView integration suite. Preserve independent sibling-repository boundaries
when a change must also be made outside `selecto_test`.
