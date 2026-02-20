# Selecto Troubleshooting Guide

> Status: evolving. APIs in this workspace are under active development.

This guide covers common issues seen in the current `selecto_test` app.

## Query Returns No Data

Checklist:

1. Confirm the selected fields exist in the configured domain.
2. Inspect active filters (including saved filter sets).
3. Check generated SQL in debug output and run it directly if needed.
4. Verify joins and join-mode metadata for lookup/star/tag style fields.

## Saved View Loads But Fails On Submit

Typical causes:

- saved config references removed/renamed columns
- view mode mismatch (`view_type` not allowed by host schema validation)
- stale graph/aggregate config after domain changes

Fix path:

1. Open View Controller and resubmit after adjusting fields.
2. Update saved config or delete/recreate problematic saved view.
3. Ensure host validation includes all active view types.

## View Tab Missing

Check:

1. View is present in `views` assign in the LiveView.
2. Module compiles and exports required view-system callbacks.
3. If dependency changed in `mix.exs`, restart the app server.

## Custom View System Renders Nothing

Check:

1. `Process.view/5` returns a valid `{view_set, view_meta}` tuple.
2. `result_component/0` points to a component that can render `@query_results`.
3. `form_component/0` module is valid and mounted.

## Errors When Toggling View Controller

Likely causes:

- invalid form state generated from params
- missing module for selected view mode
- stale saved view payload

Actions:

1. Switch to a known-good view mode (detail/aggregate/graph).
2. Rebuild the problematic saved view.
3. Inspect logs for function/module mismatch.

## Graph Appears Incorrect

Common issues:

- series aliases vs selected metrics mismatch
- axis assignment mismatch (left/right)
- unsupported series config for the selected chart type

Actions:

1. Verify y-series config and aliases.
2. Confirm chart type supports the configured series behavior.
3. Re-submit from the graph tab to rebuild state.

## Mix Task Not Found

Only documented tasks in this repo are in:

- `vendor/selecto_mix/lib/mix/tasks/`

List them:

```bash
ls vendor/selecto_mix/lib/mix/tasks
```

## Docs Page 404 / Missing

DocsLive resolves markdown files from:

- `docs/selecto-system/<path>.md`

If a link points to a missing page, either create that file or update the link.

## Practical Debug Commands

```bash
mix compile
mix test
```

Use app logs and the in-page debug panel to inspect SQL and runtime state while reproducing issues.

## Related Docs

- [Getting Started](getting-started.md)
- [Best Practices](best-practices.md)
- [API Reference](index.md)
- [System Overview](system-overview.md)

---

Last updated: 2026-02-20
