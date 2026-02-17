# Selecto 0.3 Implementation Plan

Date: 2026-02-13  
Source: `SELECTO_0_3_FINDINGS_AND_RECOMMENDATIONS.md`

## Goal

Close all ecosystem 0.3 release blockers with a phased, testable path to:
- `selecto` core `0.3.x` release (first)
- `selecto_mix` tooling hardening (second)
- `selecto_components` package-ready release candidate (third)

## Scope

In scope:
- High-severity findings 1-6
- Medium-severity findings 7-10 needed for truthful release docs and stable CI
- Targeted cleanup of low-severity findings 11-12 where they affect user trust/release messaging

Out of scope for this cycle:
- New net-new UI feature development not tied to release blockers

## Execution Model

Track work in 4 streams running in parallel where safe:
1. Packaging and build integrity (`selecto_components`)
2. API/test correctness (`selecto_components` graph stack)
3. Core/query correctness (`selecto`, `selecto_mix`)
4. Documentation and release truthfulness (all repos)

## Phase 0 - Release Baseline (Day 0-1)

### Tasks
1. Freeze a release branch for coordinated work.
2. Add a shared checklist issue with all findings mapped 1:1.
3. Create CI matrix jobs for each package:
- `vendor/selecto`
- `vendor/selecto_mix`
- `vendor/selecto_components`
4. Define a single release status board: `blocked`, `ready-for-verify`, `done`.

### Exit Criteria
- Every finding has an owner and acceptance check.
- CI jobs run independently per package.

## Phase A - Core-First Readiness (`selecto`) (Day 1-5)

### A1. Subfilter public API truthfulness (Finding 6, High)
Files:
- `vendor/selecto/lib/selecto/subfilter/registry.ex`
- `vendor/selecto/lib/selecto/subfilter/join_path_resolver.ex`

Tasks:
1. Replace placeholder SQL suffix in `generate_sql/2` with either:
- Full implementation for supported cases, or
- Explicit `{:error, :not_implemented, details}` return for unsupported cases.
2. Implement minimum viable complex path resolution for documented cases.
3. If not fully implementable now, gate advanced path logic behind explicit `experimental: true`.
4. Add tests for success + failure modes.

Acceptance:
- No placeholder SQL emitted in public API paths.
- Unsupported behavior is explicit and documented.

### A2. Hierarchy/select builder stubs (Findings 7-8, Medium)
Files:
- `vendor/selecto/lib/selecto/builder/sql/hierarchy.ex`
- `vendor/selecto/lib/selecto/builder/sql/select.ex`

Tasks:
1. Convert phase/stub internals into explicit capability boundaries.
2. Replace CTE field-detection stub path with implemented logic for supported selectors.
3. Add targeted regression tests around hierarchy + custom SQL selectors.

Acceptance:
- No hidden “for now” behavior in core query builder path without explicit guardrails.

### A3. Disabled integration tests (Finding 9, Medium)
Files:
- `vendor/selecto/test/README_DISABLED_TESTS.md`

Tasks:
1. Re-enable disabled tests where feasible.
2. For tests still blocked, add deterministic reproduction notes and skip reason tags.
3. Add CI gating for re-enabled integration coverage.

Acceptance:
- Disabled test list is reduced and justified.
- CI reflects real support boundaries.

## Phase B - Tooling Hardening (`selecto_mix`) (Day 3-7)

### B1. Parameterized join validator implementation (Finding 4, High)
Files:
- `vendor/selecto_mix/lib/mix/tasks/selecto.validate.parameterized_joins.ex`

Tasks:
1. Implement parser path currently marked unimplemented.
2. Replace hardcoded `true` validation checks with concrete validation rules.
3. Add fixture-based tests for valid/invalid join parameterizations.
4. Ensure CLI output differentiates warnings vs errors.

Acceptance:
- No unimplemented runtime path for documented validator use.
- Validator fails correctly on malformed parameterized joins.

### B2. Query helper generation/docs alignment (Finding 5, High)
Files:
- `vendor/selecto_mix/lib/mix/tasks/selecto.gen.domain.ex`
- `vendor/selecto_mix/README.md`

Tasks:
1. Decide and implement one of:
- Generate `*_queries.ex` as documented, or
- Remove promise from docs and provide alternative workflow.
2. Add test coverage asserting generator output set.
3. Update README examples to match actual generated artifacts.

Acceptance:
- Generated outputs and README promises match exactly.

## Phase C - Components Release Candidate (`selecto_components`) (Day 5-10)

### C1. Hex packaging readiness (Finding 1, High)
Files:
- `vendor/selecto_components/mix.exs`
- `vendor/selecto_components/priv/static/`

Tasks:
1. Replace local path dependency strategy with publishable version constraints.
2. Add build step to generate `priv/static/selecto_components.min.js`.
3. Ensure package file list includes only existing artifacts.
4. Validate package via local `mix hex.build`.

Acceptance:
- Package builds without missing files.
- Dependency strategy is Hex-compatible.

### C2. Graph component/test contract fixes (Findings 2-3, High)
Files:
- `vendor/selecto_components/lib/selecto_components/views/graph/component.ex`
- `vendor/selecto_components/test/selecto_components/views/graph/component_test.exs`
- `vendor/selecto_components/test/selecto_components/views/graph/integration_test.exs`

Tasks:
1. Standardize hook naming (`.GraphComponent` vs `.GraphViewHook`) in code + tests.
2. Resolve private/missing API test usage:
- Expose stable public helpers where appropriate, or
- Rewrite tests to assert public rendered behavior only.
3. Remove references to nonexistent `get_aggregate_label/1` unless added intentionally.
4. Add integration test pass criteria for graph render + interactions.

Acceptance:
- Graph tests only target public API/behavior.
- Test suite passes without private API coupling.

### C3. UI placeholder transparency (Findings 11-12, Low)
Files:
- `vendor/selecto_components/lib/selecto_components/form.ex`
- `vendor/selecto_components/lib/selecto_components/views/detail/column_config.ex`
- `vendor/selecto_components/lib/selecto_components/dashboard/widget_registry.ex`
- `vendor/selecto_components/lib/selecto_components/dashboard/layout_manager.ex`

Tasks:
1. Replace “coming soon” user-visible copy with explicit feature flags or hidden controls.
2. Gate mock/placeholder dashboard content behind dev-only mode or remove from release surface.

Acceptance:
- Production UI does not expose non-functional placeholders as ready features.

## Phase D - Docs and Version Truth (Day 8-11)

### D1. Version/docs drift cleanup (Finding 10, Medium)
Files:
- `vendor/selecto/README.md`
- `vendor/selecto/mix.exs`
- `vendor/selecto_mix/README.md`
- `vendor/selecto_mix/mix.exs`

Tasks:
1. Align README dependency snippets with actual package versions.
2. Add release-status section per repo (stable/experimental/not included).
3. Add a “known limitations” section for `selecto` advanced subfilter scope.

Acceptance:
- Install/docs examples are version-accurate.
- Experimental boundaries are explicit.

## Verification and Release Gates

## Gate 1 - Core Go (`selecto 0.3.x`)
- A1-A3 completed
- Core CI green
- Experimental limitations documented

## Gate 2 - Tooling Go (`selecto_mix 0.3.x`)
- B1-B2 completed
- Generator and validator tests green
- README matches behavior

## Gate 3 - Components RC (`selecto_components 0.3.x-rc`)
- C1-C3 completed
- Package builds and installs cleanly
- Graph tests/integration green

## Gate 4 - Ecosystem-wide 0.3 official
- D1 complete across all repos
- Cross-repo compatibility smoke test green
- Release notes published with capability matrix

## Suggested Work Breakdown (single team, ~2 weeks)

1. Days 1-2: Phase 0 + A1 kickoff
2. Days 3-5: A2/A3 + B1
3. Days 6-8: B2 + C1/C2
4. Days 9-10: C3 + D1
5. Days 11-12: Full regression, packaging, release candidates

## Risks and Mitigations

1. Risk: Graph tests require internal refactor to decouple private APIs.
- Mitigation: Prefer behavior-driven tests; expose public helpers only when reusable.

2. Risk: Subfilter/join-path work expands unexpectedly.
- Mitigation: Ship with explicit experimental scope and hard error boundaries.

3. Risk: Packaging pipeline for assets is brittle.
- Mitigation: Make JS artifact generation part of CI and release task.

## Definition of Done

1. All High findings closed (or explicitly descoped with documented, enforced boundaries).
2. Medium findings affecting release truth/CI closed.
3. No README promises behavior not present in code.
4. Ecosystem release decision can be made from green CI + checklist evidence.
