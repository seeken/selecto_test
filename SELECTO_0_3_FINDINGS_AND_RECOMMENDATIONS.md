# Selecto Ecosystem 0.3 Findings and Recommendations

Date: 2026-02-13
Scope reviewed:
- `vendor/selecto`
- `vendor/selecto_mix`
- `vendor/selecto_components`

## Findings (ordered by severity)

1. High - `selecto_components` is not publish-ready as a Hex package.
- Uses a local path dependency instead of a versioned dependency: `vendor/selecto_components/mix.exs:45`
- Package includes a missing artifact: `vendor/selecto_components/mix.exs:64` references `priv/static/selecto_components.min.js`, but file is absent.

2. High - Graph test/implementation mismatch in `selecto_components`.
- Component uses hook `.GraphComponent`: `vendor/selecto_components/lib/selecto_components/views/graph/component.ex:173`
- Tests expect `.GraphViewHook`: `vendor/selecto_components/test/selecto_components/views/graph/component_test.exs:373`, `vendor/selecto_components/test/selecto_components/views/graph/integration_test.exs:123`

3. High - Graph test suite references private or missing APIs.
- Tests call `Component.get_chart_type/1`, but it is private (`defp`): `vendor/selecto_components/lib/selecto_components/views/graph/component.ex:434`
- Tests call `Component.get_aggregate_label/1`, but no such function exists in the component module.

4. High - `selecto_mix` parameterized join validator is partially stubbed.
- Parser path explicitly unimplemented: `vendor/selecto_mix/lib/mix/tasks/selecto.validate.parameterized_joins.ex:83`
- Runtime message confirms not implemented: `vendor/selecto_mix/lib/mix/tasks/selecto.validate.parameterized_joins.ex:100`
- Validation checks mostly hardcoded to true: `vendor/selecto_mix/lib/mix/tasks/selecto.validate.parameterized_joins.ex:217`

5. High - `selecto_mix` docs promise generated query helper files that are currently skipped in code.
- README promises `*_queries.ex`: `vendor/selecto_mix/README.md:72`
- Code intentionally skips generation: `vendor/selecto_mix/lib/mix/tasks/selecto.gen.domain.ex:402`

6. High - `selecto` subfilter public API still contains placeholder behavior.
- `generate_sql/2` returns placeholder SQL suffix: `vendor/selecto/lib/selecto/subfilter/registry.ex:228`
- Complex auto path resolution explicitly not implemented: `vendor/selecto/lib/selecto/subfilter/join_path_resolver.ex:322`

7. Medium - Hierarchy SQL builder still documents/uses phase-stub behavior.
- Module still marked as phase/stub foundation: `vendor/selecto/lib/selecto/builder/sql/hierarchy.ex:8`
- Simplified and "for now" internals remain: `vendor/selecto/lib/selecto/builder/sql/hierarchy.ex:151`

8. Medium - Custom SQL selector support still has stubbed CTE-field detection.
- Stubbed CTE field detection path: `vendor/selecto/lib/selecto/builder/sql/select.ex:923`

9. Medium - `selecto` has disabled integration tests and explicitly notes incomplete support.
- Disabled tests tracked: `vendor/selecto/test/README_DISABLED_TESTS.md:1`
- Includes note about incomplete feature support in disabled CTE integration area: `vendor/selecto/test/README_DISABLED_TESTS.md:17`

10. Medium - Version/docs drift across repositories.
- `selecto` README still shows `~> 0.2.6`: `vendor/selecto/README.md:307` while `vendor/selecto/mix.exs:7` is `0.3.0`
- `selecto_mix` README still shows `~> 0.2.0`: `vendor/selecto_mix/README.md:23` while `vendor/selecto_mix/mix.exs:7` is `0.3.0`

11. Low - "Coming soon" UI sections remain user-visible in `selecto_components`.
- Export section explicitly marked coming soon: `vendor/selecto_components/lib/selecto_components/form.ex:247`
- Boolean display options marked coming soon: `vendor/selecto_components/lib/selecto_components/views/detail/column_config.ex:82`

12. Low - Dashboard/widget area is still partly mock/placeholder driven.
- Mock fetch data path: `vendor/selecto_components/lib/selecto_components/dashboard/widget_registry.ex:338`
- Layout manager widget content placeholder: `vendor/selecto_components/lib/selecto_components/dashboard/layout_manager.ex:451`

## Release Recommendation for "official 0.3"

Current recommendation: No-go for a full ecosystem-wide official `0.3` release across all three packages.

Conditional go:
- `selecto` core could be released as `0.3` if advanced subfilter limitations are clearly marked experimental and documented.

## Minimum release gates before ecosystem-wide 0.3

1. Packaging and publishability
- Fix `selecto_components` dependency strategy for Hex.
- Ensure packaged JS artifact exists and is generated as part of release.

2. Test integrity
- Resolve graph test/component API mismatches.
- Re-enable or replace disabled integration tests with reproducible CI paths.

3. Documentation accuracy
- Align all README install versions/tasks with actual code.
- Remove or explicitly label non-functional promised features.

4. Feature truthfulness
- Either implement currently stubbed public APIs (`selecto_mix` validator paths, `selecto` subfilter SQL generation) or explicitly de-scope and mark as experimental.

## Suggested phased release strategy

1. Phase A: Core-first release
- Release `selecto` `0.3.x` with explicit scope and known limitations.

2. Phase B: Tooling hardening
- Land `selecto_mix` validator/query-generation fixes and doc alignment.

3. Phase C: Component release candidate
- Make `selecto_components` packageable, align tests, then cut ecosystem-wide `0.3`.

