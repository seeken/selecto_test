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
- Status: `blocked`
- Owner: TBD

2. `selecto_components` graph hook mismatch
- Status: `blocked`
- Owner: TBD

3. `selecto_components` graph tests using private/missing APIs
- Status: `blocked`
- Owner: TBD

4. `selecto_mix` parameterized join validator implementation gaps
- Status: `blocked`
- Owner: TBD

5. `selecto_mix` query helper generation/docs mismatch
- Status: `blocked`
- Owner: TBD

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
