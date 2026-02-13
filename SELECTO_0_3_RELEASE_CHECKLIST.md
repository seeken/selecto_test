# Selecto 0.3 Release Checklist

Date started: 2026-02-13  
Source findings: `SELECTO_0_3_FINDINGS_AND_RECOMMENDATIONS.md`

Status legend:
- `blocked` = not started
- `in_progress` = partially implemented
- `ready_for_verify` = implemented, pending broader regression
- `done` = implemented and verified

## Ecosystem Findings Tracker

1. `selecto_components` Hex publishability (deps + JS artifact)
- Status: `ready_for_verify`
- Progress:
1. Replaced local path dependency with Hex-compatible version requirement for `selecto`.
2. Added `assets.package` workflow that generates `priv/static/selecto_components.min.js`.
3. Added `esbuild` package profile in `config/config.exs`.
4. Updated package file list to include real release artifacts (`README.md`, `LICENSE`, generated JS bundle).
5. Committed in `vendor/selecto_components` on branch `chore/selecto-0.3-release-work` (`f2996b7`).

2. `selecto_components` graph hook mismatch
- Status: `ready_for_verify`
- Progress:
1. Standardized graph hook contract on `.GraphComponent` and updated graph tests to assert fully qualified colocated hook output.
2. Committed in `vendor/selecto_components` on branch `chore/selecto-0.3-release-work` (`99bb5be`).

3. `selecto_components` graph tests using private/missing APIs
- Status: `ready_for_verify`
- Progress:
1. Added stable public graph helpers used by tests (`get_chart_type/1`, `get_aggregate_label/1`, `format_chart_label/1`, `format_numeric_value/1`, `generate_color/2`, `chart_summary/2`).
2. Updated graph data/option behaviors to match public contract (line datasets, pie/doughnut scale handling, chart type resolution from `selecto.set`).
3. Reworked graph integration tests to use LiveComponent rendering helpers and focus on graph workflow assertions.
4. Graph test pair passes in `MIX_ENV=test`:
- `test/selecto_components/views/graph/component_test.exs`
- `test/selecto_components/views/graph/integration_test.exs`

4. `selecto_mix` parameterized join validator implementation gaps
- Status: `ready_for_verify`
- Progress:
1. Implemented real reference parsing and join validation paths in `mix selecto.validate.parameterized_joins`.
2. Added `SelectoMix.ParameterizedJoinsValidator` with checks for parameter schema, field types, and join_condition placeholders.
3. Added automated tests for validator + task behavior.

5. `selecto_mix` query helper generation/docs mismatch
- Status: `ready_for_verify`
- Progress:
1. Removed stale `*_queries.ex` generation promises from `selecto_mix` docs and generator task messaging.
2. Dry-run and generation paths now reflect current behavior (domain + overlay generation).

6. `selecto` subfilter placeholder public API behavior
- Status: `ready_for_verify`
- Progress:
1. `Registry.generate_sql/2` now delegates to `Selecto.Subfilter.SQL.generate/1`.
2. Placeholder SQL suffix removed.
3. Base query + generated WHERE clause merging implemented.

7. `selecto` hierarchy SQL builder phase-stub behavior
- Status: `in_progress`
- Progress:
1. Module/docs updated to explicit capability language.
2. Deterministic fallback behavior preserved.

8. `selecto` CTE-field detection stub in selector support
- Status: `ready_for_verify`
- Progress:
1. CTE field detection now reads declared `selecto.set.ctes` column metadata.
2. Added test coverage for CTE-qualified custom SQL selector fields.

9. `selecto` disabled integration tests and incomplete support visibility
- Status: `ready_for_verify`
- Progress:
1. `vendor/selecto/test/README_DISABLED_TESTS.md` rewritten with deterministic failure/re-enable criteria.
2. `vendor/selecto/test/selecto_cte_integration_test.exs` re-enabled and passing.
3. `vendor/selecto/test/selecto_test.exs` re-enabled with `@moduletag :requires_db` and default exclusion in `test/test_helper.exs`.

10. Version/docs drift (`selecto`, `selecto_mix`)
- Status: `blocked`
- Owner: TBD

11. `selecto_components` user-visible “coming soon”
- Status: `blocked`
- Owner: TBD

12. `selecto_components` placeholder dashboard/widget behavior
- Status: `blocked`
- Owner: TBD

## Verification Log

2026-02-13:
1. `vendor/selecto` targeted tests passed:
- `test/selecto/subfilter/registry_test.exs`
- `test/selecto/subfilter/join_path_resolver_test.exs`
- `test/selecto/custom_sql_selector_test.exs`
2. `test/selecto_cte_integration_test.exs` now passes (`11 tests, 0 failures`) after compatibility shims.
3. `test/selecto_test.exs` is now CI-safe by default via `:requires_db` tagging and env-gated execution.
4. `vendor/selecto_mix` suite passes after validator/task implementation and docs alignment (`mix test`).
5. `vendor/selecto_components` C1 packaging flow now generates `priv/static/selecto_components.min.js` via `mix assets.package`.
6. `vendor/selecto_components` `mix hex.build` is currently blocked by local toolchain issue (`Hex 2.3.1` on OTP `28.0.1` raises `:re.import/1` error).
7. `vendor/selecto_components` graph contract tests now pass:
- `MIX_ENV=test mix test test/selecto_components/views/graph/component_test.exs test/selecto_components/views/graph/integration_test.exs --no-deps-check` (`30 tests, 0 failures`).
