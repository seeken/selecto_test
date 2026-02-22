# Selecto Test Project

This project is a test/development project for the Selecto ecosystem modules.

> ⚠️ **Alpha Software Notice**
>
> The Selecto ecosystem modules in this workspace are under active development.
> Expect breaking changes, API churn, and potentially major bugs.

## Sample Data

This project uses the **[Pagila](https://github.com/devrimgunduz/pagila)** sample database, a PostgreSQL port of the MySQL Sakila sample database. Pagila provides a rich dataset of films, actors, customers, and rental transactions that serves as an excellent testbed for Selecto's advanced query capabilities. 

This project includes the complete Selecto ecosystem in the vendor directory:
- [selecto](https://github.com/selecto-elixir/selecto) - Core query builder
- [selecto_components](https://github.com/selecto-elixir/selecto_components) - Phoenix LiveView components
- [selecto_dome](https://github.com/selecto-elixir/selecto_dome) - Data manipulation interface
- [selecto_mix](https://github.com/selecto-elixir/selecto_mix) - Mix tasks and code generation
- **selecto_dev** - Development tools and dashboard (new!)

## Livebooks, Tutorials, and Hosted Demo

- [selecto-elixir/selecto_livebooks](https://github.com/selecto-elixir/selecto_livebooks) - Livebook with many Selecto query features
- [seeken/selecto_northwind](https://github.com/seeken/selecto_northwind) - Tutorials for building Selecto queries and workflows
- [testselecto.fly.dev](https://testselecto.fly.dev) - Hosted `selecto_test` demo app

## Live Views

- `/` and `/pagila` - Actor-focused interface for [Pagila database](https://github.com/devrimgunduz/pagila)
- `/pagila_films` - Film-centric interface with ratings and categories
- `/pagila/film/:film_id` - Individual film detail pages

## Development Tools

- `/dev/dashboard` - Phoenix LiveDashboard for system metrics
- `/selecto_dev` - **SelectoDev Dashboard** with real-time monitoring:
  - Compilation tracking across all Selecto modules
  - Query performance analysis and debugging
  - Error tracking and analysis
  - Multi-project monitoring

## Additional Features

- **Livebook Integration** - Interactive notebooks in `notebooks/` directory
- **Comprehensive Testing** - 30+ test files covering all functionality
- **Development Scripts** - Helper utilities in `scripts/` directory

## Requirements

Projects using selecto_components should include Tailwind and Alpine.js as is done in this project. You also need to add the push event hook from assets/js/hooks.

## Setup

1. **Clone dependencies** (if not already present in vendor/):
   ```bash
   # All Selecto modules should be in vendor/ directory
   git clone <selecto-repo> vendor/selecto
   git clone <selecto-components-repo> vendor/selecto_components
   # etc.
   ```

2. **Install dependencies**:
   ```bash
   mix deps.get
   ```

3. **Setup database**:
   ```bash
   mix ecto.create
   mix ecto.migrate
   mix run priv/repo/seeds.exs
   ```

4. **Add Pagila data** (optional):
   - Download the [Pagila database](https://github.com/devrimgunduz/pagila)
   - Import tables and data into your dev database

5. **Start the application**:
   ```bash
   # For regular development
   mix phx.server
   
   # For Livebook connection (with named node)
   iex --sname selecto --cookie COOKIE -S mix phx.server
   ```

## Accessing the Dashboard

- **Main App**: http://localhost:4000
- **SelectoDev Dashboard**: http://localhost:4000/selecto_dev
- **Phoenix LiveDashboard**: http://localhost:4000/dev/dashboard

## Development Workflow

Use the integrated SelectoDev dashboard for:
- Real-time compilation monitoring
- Query performance analysis
- Error tracking and debugging
- Multi-project status overview

The dashboard provides a comprehensive development environment specifically tailored for Selecto ecosystem development.

## Implementing New Selecto Component Views

The formal process for creating pluggable view systems is documented in:

- `vendor/selecto_components/README.md` under `Custom View Systems`
- `vendor/selecto_components/README.md` under `Implementing A New View System`

This includes package naming conventions (`selecto_components_view_<slug>`),
required callback contracts (`SelectoComponents.Views.System`), registration
with `SelectoComponents.Views.spec/4`, saved-view type updates, and a
verification checklist.
