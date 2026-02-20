# Selecto API Reference (Workspace-Aligned)

> Status: evolving. APIs in this workspace are under active development.

This reference documents APIs and tasks that are available in this repository today.

## Selecto Core (`vendor/selecto`)

Common functions (confirmed in current runtime):

- `Selecto.configure/2`, `Selecto.configure/3`
- `Selecto.select/2`
- `Selecto.filter/2`
- `Selecto.join/2`, `Selecto.join/3`
- `Selecto.group_by/2`
- `Selecto.order_by/2`
- `Selecto.limit/2`, `Selecto.offset/2`
- `Selecto.execute/1`, `Selecto.execute/2`
- `Selecto.execute_one/1`, `Selecto.execute_one/2`
- `Selecto.to_sql/1`, `Selecto.to_sql/2`
- `Selecto.with_cte/3`, `Selecto.with_cte/4`
- `Selecto.window_function/3`, `Selecto.window_function/4`
- `Selecto.union/2`, `Selecto.union/3`

Notes:

- In this workspace, filtering and joins are often produced by component/process modules rather than manually in LiveView.
- `Selecto.execute*` returns structured tuples suitable for explicit error handling.

## SelectoComponents (`vendor/selecto_components`)

Primary modules:

- `SelectoComponents.Form`
- `SelectoComponents.Results`
- `SelectoComponents.Views`

Built-in view systems:

- `SelectoComponents.Views.Detail`
- `SelectoComponents.Views.Aggregate`
- `SelectoComponents.Views.Graph`

View registration:

- Recommended: `SelectoComponents.Views.spec/4`
- Compatible legacy form: `{id, module, name, options}` tuple

## Formal Custom View Contract

Use `SelectoComponents.Views.System`.

Required callbacks:

- `initial_state/2`
- `param_to_state/2`
- `view/5`
- `form_component/0`
- `result_component/0`

Runtime resolution is handled by `SelectoComponents.Views.Runtime`.

## Mix Tasks (`vendor/selecto_mix`)

Available tasks in this workspace:

- `mix selecto.add_timeouts`
- `mix selecto.components.integrate`
- `mix selecto.gen.domain`
- `mix selecto.gen.filter_sets`
- `mix selecto.gen.live_dashboard`
- `mix selecto.gen.parameterized_join`
- `mix selecto.gen.saved_view_configs`
- `mix selecto.gen.saved_views`
- `mix selecto.validate.parameterized_joins`

## Routes In This App

- `/pagila`
- `/pagila_films`
- `/docs/selecto-system/*`

## Recommended References

- `vendor/selecto_components/README.md`
- `vendor/selecto/lib/selecto.ex`
- `vendor/selecto_mix/lib/mix/tasks/`

## Related Docs

- [Getting Started](getting-started.md)
- [Best Practices](best-practices.md)
- [Troubleshooting](troubleshooting.md)
- [System Overview](system-overview.md)

---

Last updated: 2026-02-20
