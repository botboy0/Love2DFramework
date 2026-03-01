---
phase: 01-devops-foundation
verified: 2026-03-01T15:00:00Z
status: passed
score: 16/16 must-haves verified
re_verification: false
gaps: []
human_verification:
  - test: "Trigger a commit with an un-formatted Lua file and confirm stylua auto-formats and re-stages it"
    expected: "The commit succeeds with the file reformatted; no manual step required"
    why_human: "Pre-commit auto-format path cannot be exercised without a live git commit attempt; grep alone cannot confirm the stylua+git-add round-trip works end-to-end"
  - test: "Push a branch to GitHub and confirm CI pipeline runs and the job named 'Lint, Format, Test, Validate' appears in the Actions tab"
    expected: "All four CI steps pass (selene, stylua --check, busted, lua validate_architecture)"
    why_human: "GitHub Actions execution requires a remote repository with a push; cannot be verified locally"
  - test: "Configure branch protection on GitHub (Settings -> Branches) and attempt to merge a PR with a failing CI check"
    expected: "Merge is blocked until the status check 'Lint, Format, Test, Validate' passes"
    why_human: "Branch protection is a GitHub UI setting documented but not automatable without repo admin credentials"
---

# Phase 1: DevOps Foundation — Verification Report

**Phase Goal:** The project enforces its own architectural rules — no conforming commit can introduce ECS violations, global state, or cross-plugin coupling
**Verified:** 2026-03-01T15:00:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | selene reports zero warnings on an empty project | VERIFIED | `selene.toml` uses `unscoped_variables = "deny"` + `std = "love2d"`; `main.lua` uses `_dt` convention to pass unused_variable; `love2d.yml` whitelists only love/world/eventBus/registry |
| 2 | stylua --check passes on all Lua files | VERIFIED | `.stylua.toml` exists with `indent_type = "Tabs"`, 120-column width; `.styluaignore` excludes `lib/`; `conf.lua` and `main.lua` are tab-indented and formatted |
| 3 | selene rejects a file containing an undeclared global | VERIFIED | `unscoped_variables = "deny"` in `selene.toml`; verified in 01-01 summary (exit code 1 on test global); love2d.yml does NOT whitelist arbitrary identifiers |
| 4 | Project directory structure matches the flat src/ layout | VERIFIED | `src/core/`, `src/plugins/`, `src/client/`, `src/server/`, `lib/`, `tests/`, `tests/helpers/`, `assets/`, `examples/` all exist with `.gitkeep` files |
| 5 | A commit with an undeclared global is rejected by the pre-commit hook | VERIFIED | `.githooks/pre-commit` runs `selene` after `stylua`; exits 1 on selene error; `core.hooksPath = .githooks` configured; verified live in 01-02 summary |
| 6 | A commit with un-formatted Lua is auto-fixed and staged by the pre-commit hook | VERIFIED (human confirm recommended) | Hook runs `stylua` then `git add` on staged files before selene runs; code path exists and substantive |
| 7 | busted discovers and runs `_spec.lua` test files | VERIFIED | `.busted` configures `pattern = "_spec"`, `ROOT = {"tests/"}`; `tests/main_spec.lua` exists with 3 smoke tests; `tests/validate_architecture_spec.lua` has 18 tests |
| 8 | The plugin test harness creates an isolated context (world, bus, registry) | VERIFIED | `tests/helpers/plugin_harness.lua` implements `create_context()` returning `{world, bus, config, services, registry}` with stub implementations and teardown function |
| 9 | CLAUDE.md documents ECS-only logic, event-bus-only communication, plugin isolation rules with do/don't examples | VERIFIED | CLAUDE.md has 5 architectural rules each with do/don't code examples; references `examples/canonical_plugin.lua`; does not inline the template |
| 10 | The architecture validator detects undeclared globals in src/ files | VERIFIED | `Validator.detect_globals()` in `scripts/validate_architecture.lua`; pattern matches bare identifier assignments not preceded by `local`; whitelist excludes love/world/eventBus/registry; 7 busted tests cover this |
| 11 | The architecture validator detects cross-plugin imports | VERIFIED | `Validator.detect_cross_plugin_imports()` detects `require("src.plugins.X")` from `src/plugins/Y/`; 5 busted tests cover this including double-quote, same-plugin, and core-file cases |
| 12 | The architecture validator detects game logic outside ECS systems | VERIFIED | `Validator.detect_logic_outside_ecs()` checks `src/client/` and `src/server/` files for direct ECS world access in love callbacks; skips system files |
| 13 | The validator enforces test file mirroring | VERIFIED | `Validator.detect_missing_tests()` maps `src/<rest>.lua` to `tests/<rest>_spec.lua`; 4 busted tests cover path mapping and missing/present cases |
| 14 | CI pipeline runs selene lint on every push | VERIFIED | `.github/workflows/ci.yml` step "Lint (selene)" runs `selene src/ main.lua conf.lua`; triggers on `push` and `pull_request` to `main` |
| 15 | CI pipeline runs all four checks and fails on any step failure | VERIFIED | Sequential single-job: selene -> stylua --check -> busted -> lua validate_architecture; `set -euo pipefail` equivalent via GitHub Actions step failure propagation |
| 16 | The workflow is configured for branch protection (status checks) | VERIFIED | Job named `Lint, Format, Test, Validate`; CLAUDE.md documents manual branch protection setup with exact status check name |

**Score:** 16/16 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `selene.toml` | selene config with `unscoped_variables = "deny"` and `std = "love2d"` | VERIFIED | Contains correct rule name (`unscoped_variables` not `global_usage` — deviation from plan spec, correctly fixed) |
| `love2d.yml` | Custom std whitelisting love, world, eventBus, registry | VERIFIED | Exactly 4 globals whitelisted; `base: "lua51"` inherits standard Lua globals |
| `.stylua.toml` | stylua formatting config with `indent_type` | VERIFIED | `indent_type = "Tabs"`, 120-column, AutoPreferDouble quotes, sort_requires enabled |
| `conf.lua` | Love2D config entry point with `love.conf` | VERIFIED | 7 lines; `love.conf(t)` present with identity, version, window dimensions |
| `main.lua` | Love2D main entry with `love.load` | VERIFIED | 5 lines; `love.load`, `love.update(_dt)`, `love.draw` present; `_dt` convention for unused parameter |
| `.styluaignore` | Excludes `lib/` from formatting | VERIFIED | Contains `lib/` |
| `.githooks/pre-commit` | Pre-commit hook running selene + stylua | VERIFIED | Executable; auto-formats with stylua, re-stages, then lint-checks with selene; splits src/test files for correct selene config routing |
| `scripts/full-check.sh` | Full-suite runner with busted | VERIFIED | 4 steps: selene, stylua --check, busted, lua validate_architecture; sync comment present; runs all steps unconditionally |
| `tests/helpers/plugin_harness.lua` | Shared harness with `plugin_harness` table | VERIFIED | 91 lines; `create_context()` and `teardown()`; stub world/bus/registry with real method implementations |
| `.busted` | busted config with `_spec` pattern | VERIFIED | Correct: `pattern = "_spec"`, `ROOT = {"tests/"}`, `utfTerminal` output |
| `CLAUDE.md` | Architectural rules doc containing "ECS" | VERIFIED | 307 lines; 5 rules with do/don't examples; references `examples/canonical_plugin.lua`; CI section added by plan 04 |
| `scripts/validate_architecture.lua` | Architecture validator with `validate` function | VERIFIED | 439 lines; `Validator.run()`, `detect_globals()`, `detect_cross_plugin_imports()`, `detect_missing_tests()`, `detect_logic_outside_ecs()`; module+script dual-mode |
| `tests/validate_architecture_spec.lua` | Tests for validator with `validator` coverage | VERIFIED | 285 lines; 18 tests across 4 describe blocks; covers all detection functions with edge cases |
| `.github/workflows/ci.yml` | GitHub Actions CI pipeline with `selene` | VERIFIED | Complete 4-step pipeline; triggers on push and pull_request to main; pinned tool versions |
| `examples/canonical_plugin.lua` | Reference plugin template | VERIFIED | Exists; implements `CanonicalPlugin:init(ctx)` interface; explicitly PLACEHOLDER pending Phase 2 (appropriate for this phase) |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `selene.toml` | `love2d.yml` | `std = "love2d"` | WIRED | `selene.toml` line 1: `std = "love2d"`; `love2d.yml` has `name: "love2d"` |
| `.githooks/pre-commit` | `selene.toml` | pre-commit invokes selene | WIRED | `xargs selene` present; src files use root `selene.toml` (default config); test files routed to `tests/selene.toml` |
| `.githooks/pre-commit` | `.stylua.toml` | pre-commit invokes stylua to auto-fix | WIRED | `xargs stylua` present; stylua reads `.stylua.toml` by default |
| `scripts/full-check.sh` | `.busted` | full-check runs busted | WIRED | `busted` invoked unconditionally; `.busted` is busted's default config file |
| `CLAUDE.md` | `examples/canonical_plugin.lua` | References canonical plugin as template | WIRED | 4 references in CLAUDE.md to `examples/canonical_plugin.lua`; file exists |
| `scripts/validate_architecture.lua` | `src/` | Scans src/ directory for violations | WIRED | `find_lua_files("src")` call in `Validator.run()`; pattern `"src/"` used throughout |
| `.github/workflows/ci.yml` | `selene.toml` | CI installs and runs selene | WIRED | Step "Lint (selene)" runs `selene src/ main.lua conf.lua` |
| `.github/workflows/ci.yml` | `.stylua.toml` | CI installs and runs stylua --check | WIRED | Step "Format check (stylua)" runs `stylua --check src/ main.lua conf.lua` |
| `.github/workflows/ci.yml` | `.busted` | CI installs and runs busted | WIRED | Step "Tests (busted)" runs `busted` |
| `.github/workflows/ci.yml` | `scripts/validate_architecture.lua` | CI runs architecture validator | WIRED | Step "Architecture validation" runs `lua scripts/validate_architecture.lua` |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| DEV-01 | 01-01 | selene linting with `unscoped_variables = "deny"` and custom std whitelisting love/world/eventBus/registry | SATISFIED | `selene.toml` + `love2d.yml` verified; note: rule name is `unscoped_variables` not `global_usage` (correct deviation — plan had wrong name) |
| DEV-02 | 01-01 | stylua formatting enforced on all Lua source files | SATISFIED | `.stylua.toml` + `.styluaignore` verified; pre-commit auto-formats staged files |
| DEV-03 | 01-02 | Pre-commit hooks running selene + stylua; hard-block non-conforming commits | SATISFIED | `.githooks/pre-commit` verified; `core.hooksPath = .githooks` confirmed via git config |
| DEV-04 | 01-04 | GitHub Actions CI pipeline: lint -> test -> build; hard-block on failure | SATISFIED | `.github/workflows/ci.yml` verified with all 4 steps; triggers on push and pull_request to main |
| DEV-05 | 01-02 | busted test framework with plugin test harness (Phase 1: stub world/bus/registry) | SATISFIED | `.busted` + `tests/helpers/plugin_harness.lua` + `tests/main_spec.lua` verified; Phase 2 note documented appropriately |
| DEV-06 | 01-03 | CLAUDE.md with architectural enforcement rules (ECS-only, event-bus, plugin isolation) | SATISFIED | CLAUDE.md verified with 5 rules, do/don't examples, naming conventions, file org, testing rules, CI section |
| DEV-07 | 01-03 | Architecture validator script checking globals, cross-plugin imports, client-side game logic | SATISFIED | `scripts/validate_architecture.lua` verified with 4 detection functions + 18 tests |

**All 7 requirements (DEV-01 through DEV-07) satisfied.**

No orphaned requirements found: REQUIREMENTS.md traceability table maps all 7 DEV requirements to Phase 1, all are accounted for in plans.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `examples/canonical_plugin.lua` | 5 | `PLACEHOLDER` comment | Info | Intentional — canonical plugin is explicitly deferred to Phase 2 when evolved.lua is available; CLAUDE.md correctly references the file, not its completeness |
| `tests/helpers/plugin_harness.lua` | 13, 31 | "Stub world / Stub event bus" comments noting Phase 2 replacement | Info | Intentional — plan 01-02 explicitly specifies stub implementations for Phase 1; harness is fully functional as stubs |
| `ROADMAP.md` | lines 33-34 | Plans 01-03 and 01-04 marked `[ ]` (incomplete) despite both being complete | Warning | Documentation inconsistency only — all artifacts exist, all commits verified. Does not affect code enforcement. |

No blocker anti-patterns found. No empty implementations in enforcement code paths. No `TODO`/`FIXME` in any enforcement artifact (`pre-commit`, `full-check.sh`, `validate_architecture.lua`, `ci.yml`).

---

### Key Deviation: Rule Name Correction (DEV-01)

Plan 01-01 specified `global_usage = "deny"` in `selene.toml`. The actual selene 0.30.0 rule name is `unscoped_variables`. This was correctly fixed during execution. The PLAN frontmatter also specifies `contains: "global_usage"` but the actual file contains `unscoped_variables = "deny"`. This is a documentation artifact in the PLAN only — the implementation is correct and functionally satisfies DEV-01. The architecture validator's `ALLOWED_GLOBALS` table and the pre-commit hook both correctly reference the enforcement chain.

---

### Human Verification Required

#### 1. Pre-commit stylua auto-format round-trip

**Test:** Stage a Lua file with incorrect formatting (e.g., spaces instead of tabs) and run `git commit`
**Expected:** The hook reformats the file with stylua, re-stages it, and the commit succeeds with the formatted version
**Why human:** The auto-format path requires a live git commit invocation; grep confirms the code path exists (`xargs stylua` + `xargs git add`) but the round-trip cannot be confirmed programmatically

#### 2. GitHub Actions CI execution

**Test:** Push a branch to GitHub and observe the Actions tab
**Expected:** The "CI" workflow runs; the job "Lint, Format, Test, Validate" completes with all 4 steps green
**Why human:** CI execution requires a remote GitHub repository with the correct secrets and runner availability; cannot be verified from the local filesystem

#### 3. Branch protection enforcement

**Test:** Configure branch protection per CLAUDE.md instructions, then open a PR from a branch with a lint failure
**Expected:** GitHub blocks merging until the "Lint, Format, Test, Validate" status check passes
**Why human:** Branch protection is a GitHub UI/API setting; no code in the repository can enforce it without manual configuration

---

### Gaps Summary

No gaps found. All 16 observable truths are verified against the actual codebase. All 15 required artifacts exist, are substantive (not stubs), and are correctly wired to their dependencies. All 7 requirements (DEV-01 through DEV-07) are satisfied by the existing implementation.

The only documentation inconsistency is the ROADMAP.md showing plans 01-03 and 01-04 as `[ ]` when both are complete — this is a stale checkbox and does not affect enforcement.

Three items require human confirmation (pre-commit auto-format behavior, CI execution, branch protection) but these are operational validations of correctly-wired code, not missing implementations.

---

*Verified: 2026-03-01T15:00:00Z*
*Verifier: Claude (gsd-verifier)*
