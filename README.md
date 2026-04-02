# Selecto Test Project

`selecto_test` is the main Phoenix demo and integration app for the Selecto ecosystem.

Use it when you want to:

- run a real Selecto app locally
- exercise `selecto`, `selecto_components`, and related packages together
- test against Pagila-style relational data
- try new query UI and view-system behavior in a live app

> Alpha software. This app intentionally tracks actively changing ecosystem packages.

## What It Contains

- Pagila-backed demo flows for actor and film exploration
- multiple Selecto LiveViews and result views
- LiveDashboard and Selecto development tooling
- optional PostGIS and IMDb expansion paths for broader testing

## Main Routes

- `/` or `/pagila` - actor-focused Pagila explorer
- `/pagila_films` - film-focused explorer
- `/pagila/film/:film_id` - film detail page
- `/dev/dashboard` - Phoenix LiveDashboard
- `/selecto_dev` - Selecto development dashboard

Hosted demo:

- `https://testselecto.fly.dev`

## Setup

```bash
mix deps.get
mix ecto.create
mix ecto.migrate
mix run priv/repo/seeds.exs
mix phx.server
```

For Livebook-connected development:

```bash
iex --sname selecto --cookie COOKIE -S mix phx.server
```

## Sample Data

The app is built around the Pagila sample database, a PostgreSQL port of Sakila.

That gives the demo a rich relational dataset for joins, aggregates, filters, and drill-down behavior.

## Optional Add-Ons

### PostGIS

If you want map-oriented workflows:

```bash
SELECTO_ECOSYSTEM_USE_LOCAL=true mix deps.get
```

Then enable PostGIS in the database:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

Full recipe:

- `docs/selecto-system/postgis-recipe.md`

### IMDb Import

If you want a much larger movie-only dataset in the existing film tables:

```bash
mix imdb.import
```

Useful options:

```bash
mix imdb.import --no-download
mix imdb.import --limit-movies 5000
mix imdb.import --prune
```

## Development Notes

- assets and colocated hooks follow the normal `selecto_components` setup rules
- this repo is the practical place to validate end-to-end ecosystem changes
- the most formal custom view-system guidance lives in `selecto_components/README.md`

## Tutorials And Related Repos

- `selecto_livebooks`
- `selecto_northwind`
- `selecto`
- `selecto_components`
- `selecto_mix`
- `selecto_updato`
