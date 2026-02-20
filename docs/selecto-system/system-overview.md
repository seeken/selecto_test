# Selecto Ecosystem - System Overview

> Status: evolving. APIs in this workspace are under active development.

This guide describes what is actually present in this repository and how the pieces fit together.

## Architecture Overview

The current project (`selecto_test`) is a Phoenix LiveView app that uses local vendor packages from the Selecto ecosystem.

Core runtime stack in this workspace:

- `selecto` - SQL/query builder and execution layer.
- `selecto_components` - LiveView form/results UI, tabs, filters, and built-in views.
- `selecto_mix` - generators and integration Mix tasks.
- Phoenix + LiveView + Ecto/Postgrex - host application framework.

## What This App Exposes

- `/pagila` - actor-focused Selecto UI
- `/pagila_films` - film-focused Selecto UI
- `/docs/selecto-system/*` - markdown documentation renderer

## Selecto Core (`selecto`)

Purpose:

- configure a query context from a domain map
- build query set operations (select/filter/group/order/join/etc.)
- execute safely with structured error tuples

Representative API (current):

- `Selecto.configure/2` and `Selecto.configure/3`
- `Selecto.select/2`
- `Selecto.filter/2`
- `Selecto.join/2` and `Selecto.join/3`
- `Selecto.group_by/2`
- `Selecto.order_by/2`
- `Selecto.execute/1` and `Selecto.execute/2`
- `Selecto.execute_one/1` and `Selecto.execute_one/2`

## Selecto Components (`selecto_components`)

Purpose:

- LiveView UI to configure and execute Selecto queries
- built-in `detail`, `aggregate`, and `graph` view systems
- persisted view/filter workflows in host apps

Primary modules used by host LiveViews:

- `SelectoComponents.Form`
- `SelectoComponents.Results`
- `SelectoComponents.Views`

Built-in view systems:

- `SelectoComponents.Views.Detail`
- `SelectoComponents.Views.Aggregate`
- `SelectoComponents.Views.Graph`

### Formal View-System Interface

`selecto_components` now supports pluggable view systems through:

- `SelectoComponents.Views.System` (behavior + helper macro)
- `SelectoComponents.Views.spec/4` (canonical registration tuple)

A custom view package should provide a top-level view module and wire these callbacks:

- `initial_state/2`
- `param_to_state/2`
- `view/5`
- `form_component/0`
- `result_component/0`

## Selecto Mix Tasks (`selecto_mix`)

Tasks currently available in this workspace include:

- `mix selecto.gen.domain`
- `mix selecto.gen.saved_views`
- `mix selecto.gen.saved_view_configs`
- `mix selecto.gen.filter_sets`
- `mix selecto.components.integrate`
- `mix selecto.gen.live_dashboard`
- `mix selecto.gen.parameterized_join`
- `mix selecto.validate.parameterized_joins`
- `mix selecto.add_timeouts`

## View Registration Pattern

In host LiveViews, views are registered like this:

```elixir
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
```

Custom view packages (for example `workflow_inbox`, `faceted_product`) are added in the same list with their own modules.

## Saved View Types

Saved views are stored by `view_type` in this app. If you add new view systems, update allowed `view_type` values in the host schema/context so save/load works for those modes.

## Documentation Map

These docs exist in this repository:

- [System Overview](system-overview.md)
- [Getting Started](getting-started.md)
- [Best Practices](best-practices.md)
- [Troubleshooting](troubleshooting.md)
- [Index](index.md)

## Accuracy Notes

This page is intentionally scoped to what is present in this repository today. Avoid assuming other ecosystem packages or tasks are active unless they are explicitly configured in `mix.exs` and wired into app code.

---

Last updated: 2026-02-20
