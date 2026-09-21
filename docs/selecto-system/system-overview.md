# Selecto System Overview

`selecto_test` is a Phoenix host around four sibling packages:

- `selecto` — domain normalization and governed query construction
- `selecto_db_postgresql` — PostgreSQL execution adapter
- `selecto_views` — self-contained LiveView Explorer
- `selecto_mix` — development and generation tasks

`PagilaLive` chooses the actor or film domain, configures Selecto with
`SelectoTest.Repo`, and renders `SelectoViews.Explorer`. The Explorer owns
draft versus applied state, field/filter selection, view switching, query
execution, result rendering, pagination, and aggregate drilldown.

The host endpoint serves the packaged Explorer stylesheet. No
`selecto_components` process, hook bundle, router delegation, or callback macro
is part of the runtime.
