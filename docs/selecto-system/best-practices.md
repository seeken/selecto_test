# Selecto Best Practices

> Status: evolving. APIs in this workspace are under active development.

This guide focuses on practices that match the current `selecto_test` implementation.

## Domain Design

- Keep one domain focused on one exploration context.
- Define clear column metadata (types, names, join intent).
- Prefer explicit defaults (`default_selected`, `default_group_by`, `default_order_by`) so first render is useful.

## Query Construction

- Build from `Selecto.configure(domain, repo)` and keep transformations composable.
- Add filters early to reduce result size.
- Always apply `limit/offset` or view-level pagination for large datasets.
- Use `Selecto.to_sql/1` or debug panel output to inspect generated SQL when behavior is unclear.

## LiveView Integration

- Use `use SelectoComponents.Form` and initialize with `get_initial_state/2`.
- Configure views explicitly in `views` assign.
- Prefer `SelectoComponents.Views.spec/4` for readability and consistency.
- Keep component IDs stable and unique.

## View Systems

- For built-ins, use:
  - `SelectoComponents.Views.Detail`
  - `SelectoComponents.Views.Aggregate`
  - `SelectoComponents.Views.Graph`
- For custom systems, implement the formal contract (`SelectoComponents.Views.System`) rather than relying on naming convention only.

## Saved View Hygiene

- Keep saved view names stable and descriptive.
- Add migration-safe guards for missing/renamed fields.
- If you validate `view_type`, update allowed types whenever adding a new view tab.

## Performance

- Add DB indexes for fields heavily used in filter/join/order operations.
- Watch query complexity in aggregate and graph modes.
- Use staged narrowing (date/status/account filters first) before wide groupings.

## Debugging Workflow

1. Reproduce in UI.
2. Inspect generated SQL and params (debug panel/logs).
3. Run SQL directly if needed.
4. Fix domain metadata or view process logic.
5. Re-test in both form submission and saved-view load paths.

## Testing

- Add tests for view-process modules (`initial_state`, `param_to_state`, `view`).
- Add LiveView tests for tab switch, submit, drill-down, and saved-view reload.
- Keep one smoke test per major route (`/pagila`, `/pagila_films`).

## Next

- [Troubleshooting](troubleshooting.md)
- [API Reference](index.md)

---

Last updated: 2026-02-20
