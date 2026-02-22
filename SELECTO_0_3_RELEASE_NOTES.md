# Selecto Ecosystem 0.3 Release Notes

Date: 2026-02-13  
Scope: `selecto`, `selecto_mix`, `selecto_components` (workspace vendor repos on branch `chore/selecto-0.3-release-work`)

## Release Summary

This release line consolidates the `0.3.x` baseline across core query building,
mix tooling, and LiveView components. Version/docs drift is resolved,
cross-repo smoke checks are green, and package boundaries are now explicitly
documented.

The ecosystem packages in this cycle should be treated as
**alpha-quality software**: breaking changes and major bugs are still possible.

## Capability Matrix

| Package | Version | Release Status | Included in 0.3 Scope | Experimental / Limited | Not Included |
|---|---|---|---|---|---|
| `selecto` | `0.3.0` | Alpha core | Core query building, joins, CTE support, standard select/filter/order execution paths (subject to breaking changes) | Advanced subfilters remain experimental for broad domain coverage (`Selecto.Subfilter.Parser`, `Selecto.Subfilter.Registry`, `Selecto.Subfilter.SQL`) | Code generation and UI layers |
| `selecto_mix` | `0.3.0` | Alpha tooling | Domain generation, overlay generation/update, customization-preserving regeneration (subject to breaking changes) | Parameterized join validation coverage is implemented and still evolving for edge cases | Runtime `*_queries.ex` helper generation |
| `selecto_components` | `0.3.0` | Alpha component surface | Packaging flow (`mix assets.package`), graph contract/test alignment, placeholder gating and clearer UX messaging (subject to breaking changes) | Some dashboard/widget paths require explicit production data integration; mock data is dev/test-only unless explicitly enabled | Turnkey production dashboard data backends |

## Key Changes in This Cycle

1. Documentation truthfulness
- `selecto` install/version docs aligned to `0.3.0`.
- `selecto_mix` docs aligned with actual generator behavior (no `*_queries.ex` generation claim).
- Release status and scope boundaries documented in both package READMEs.

2. Core behavior hardening
- `selecto` subfilter registry SQL generation uses real SQL generation/merge behavior (no placeholder suffix path).

3. Component behavior hardening
- Graph contracts/tests aligned.
- User-visible “coming soon” placeholders replaced with explicit gating/behavior messaging.
- Dashboard mock content gated to dev/test (or explicit override).

## Verification Snapshot

Cross-repo compatibility smoke checks from root project:

1. `MIX_ENV=test mix deps.compile selecto selecto_mix selecto_components --force`
2. `MIX_ENV=test mix compile`
3. `MIX_ENV=test mix test test/selecto_components_error_handling_test.exs test/selecto_components_auto_pivot_unit_test.exs test/selecto_array_operations_simple_test.exs --no-deps-check` (`41 tests, 0 failures`)
4. `MIX_ENV=test mix help selecto.gen.domain`
5. `MIX_ENV=test mix help selecto.validate.parameterized_joins`

## Post-Checklist Cleanup Addendum (2026-02-20)

1. `selecto` packaging hygiene
- Removed misplaced top-level `:licenses` metadata in `vendor/selecto/mix.exs`.
- Added explicit `package/0` `files:` whitelist to avoid publishing local machine artifacts.
- Re-ran `mix hex.build` successfully (`selecto-0.3.0.tar`).

2. API surface cleanup reflected in docs/changelog
- Recorded removed modules in `vendor/selecto/CHANGELOG.md`:
  - `Selecto.Connection`
  - `Selecto.OptionProvider`
  - `Selecto.QueryTimeoutMonitor`
  - `Selecto.PhoenixHelpers`
  - `Selecto.Performance.Optimizer`

3. Obsolete plan cleanup
- Removed `docs/plans/obsoleted/SELECTO_MYSQL_MSSQL_PLAN.md`.
- Updated plan references to `docs/plans/universal-database-support-plan.md`.

4. Regression checks after cleanup
- `vendor/selecto`: `mix test --no-deps-check` (`784 tests, 0 failures`, `4 excluded`).
- Root smoke tests remain green for `selecto` + `selecto_components` integration paths.

5. Alpha messaging alignment
- Added explicit alpha-quality warnings in:
  - `vendor/selecto/README.md`
  - `vendor/selecto_mix/README.md`
  - `vendor/selecto_components/README.md`

## Known Release Notes Constraints

1. `selecto_components` Hex build was previously observed blocked in this environment by local toolchain behavior (`Hex 2.3.1` + OTP `28.0.1`).
2. Non-critical compile warnings remain across repos; these are tracked separately from `0.3` scope alignment.

## Release Decision Record

For this workspace branch, Gate 4 requirement “release notes published with capability matrix” is satisfied by this document.  
Use with `SELECTO_0_3_RELEASE_CHECKLIST.md` as the authoritative execution log.
