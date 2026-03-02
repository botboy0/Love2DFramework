---
phase: 02-plugin-infrastructure
verified: 2026-03-02T00:30:00Z
status: passed
score: 4/4 success criteria verified
re_verification: false
---

# Phase 2: Plugin Infrastructure Verification Report

**Phase Goal:** The canonical plugin pattern is codified in a reference file and every plugin can be loaded and tested in isolation without sibling plugins
**Verified:** 2026-03-02
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `examples/canonical_plugin.lua` loads cleanly and demonstrates component registration, system registration, and event handling with no game-specific concepts | VERIFIED | File exists at 97 lines. Demonstrates: `evolved.id(2)` for component fragments, `evolved.builder()` query, `ctx.bus:on()` event subscription, `ctx.services:register()`, `ctx.config.tick_rate` read. No game-specific concepts. |
| 2 | A test using `tests/helpers/plugin_harness.lua` that accesses an undeclared service dependency fails with a clear error message | VERIFIED | `plugin_harness_spec.lua` line 25: `it("errors when plugin accesses undeclared service in strict mode")` — asserts `has_error` on `ctx.services:get("crafting")` when only `"inventory"` is in `allowed_deps`. Harness `make_dep_enforced_services` proxy raises `error("Plugin accessed undeclared service 'X' -- add it to deps", 2)`. |
| 3 | Running the architecture validator on a plugin file containing `evolved.spawn(` or `evolved.id(` produces a CI failure with the offending line identified | VERIFIED | `validate_architecture_spec.lua` lines 276-396: 11 tests for `detect_raw_ecs_calls` covering direct calls, alias assignments, comment exclusion, path guards. Function wired into `Validator.run()` as Check 5; errors increment `error_count`; entry point calls `os.exit(1)` when `errs > 0`. |
| 4 | The architecture validator flags a `ctx.services:get("X")` call that is not listed in the plugin's declared `deps` | VERIFIED | `validate_architecture_spec.lua` lines 403-523: 7 tests for `detect_undeclared_service_deps` covering undeclared calls, declared calls allowed, missing deps declaration, empty deps, subdirectory scanning, both quote styles, missing init.lua. Function wired into `Validator.run()` as Check 6; both error tables increment `error_count`. |

**Score:** 4/4 success criteria verified

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `examples/canonical_plugin.lua` | Config usage demonstration in init | VERIFIED | Line 45: `local _tick_rate = ctx.config.tick_rate or 60`. Contains component reg (`evolved.id(2)`), system query (`evolved.builder()`), event handling (`ctx.bus:on`), service registration (`ctx.services:register`). 97 lines — substantive. |
| `tests/canonical_plugin_spec.lua` | Test for config access in canonical plugin | VERIFIED | Lines 99-121: `describe("config access")` with 2 tests — `tick_rate = 30` and empty config. 37 total test cases covering init, update, event handling, shutdown. |
| `tests/helpers/plugin_harness.lua` | Services dependency enforcement proxy | VERIFIED | Lines 31-71: `make_dep_enforced_services` function. Lines 107-112: proxy installed when `opts.allowed_deps` provided. Contains `allowed_deps` keyword. 4.7k, substantive. |
| `tests/helpers/plugin_harness_spec.lua` | Tests for harness dep enforcement | VERIFIED | 7 test cases: ctx shape, dep pre-registration, strict mode error, declared access allowed, tolerant mode no-error, register() delegation, no-proxy when allowed_deps nil. Contains `"undeclared"` in test assertions. |
| `scripts/validate_architecture.lua` | `detect_raw_ecs_calls` + `detect_undeclared_service_deps` + verbose flag + error/warning split in `run()` | VERIFIED | `detect_raw_ecs_calls` at line 380; `detect_undeclared_service_deps` at line 488; `parse_declared_deps` local helper at line 463; `format_verbose` at line 552; `print_warning_section` at line 592; `Validator.run()` returns `(error_count, warning_count)`; entry point exits 1 on errors, 0 on warnings-only. 839 lines — substantive. |
| `tests/validate_architecture_spec.lua` | Tests for raw ECS call detection and undeclared service dep detection | VERIFIED | 11 tests for `detect_raw_ecs_calls` (lines 276-397); 7 tests for `detect_undeclared_service_deps` (lines 403-523); integration smoke test updated for dual return. 38 total test cases. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `tests/helpers/plugin_harness.lua` | `src/core/context.lua` | `make_dep_enforced_services` proxy wrapping `ctx.services` from `Context.new()` | WIRED | Line 82: `Context.new({...})` called. Line 111: `ctx.services = make_dep_enforced_services(ctx.services, ...)` replaces the real services object with the enforcement proxy. Pattern `make_dep_enforced_services` confirmed present. |
| `scripts/validate_architecture.lua detect_raw_ecs_calls` | `Validator.run()` | Called for each plugin file; errors increment `error_count`, warnings increment `warning_count` | WIRED | Lines 716-752: loop over `plugin_files`, calls `detect_raw_ecs_calls(path, file_lines)`, accumulates into `ecs_errors` / `ecs_warnings`, adds `#ecs_errors` to `error_count`. |
| `scripts/validate_architecture.lua detect_undeclared_service_deps` | `Validator.run()` | Called per plugin directory; errors and dep_parse_errors both increment `error_count` | WIRED | Lines 755-799: deduplicates plugin dirs via `plugin_dirs_seen`, calls `detect_undeclared_service_deps(plugin_dir)`, accumulates both error tables into `error_count`. |
| `scripts/validate_architecture.lua run()` | Script entry point | Returns `(error_count, warning_count)`; entry point exits 1 on `errs > 0` | WIRED | Lines 823-835: `local errs, warns = Validator.run(...)`, `os.exit(0)` when `errs == 0`, `os.exit(1)` otherwise. |
| `scripts/validate_architecture.lua parse_declared_deps` | `detect_undeclared_service_deps` | Parses `MyPlugin.deps = { ... }` from init.lua lines before scanning plugin files | WIRED | Line 503: `local declared_deps = parse_declared_deps(init_lines)`. Local function at line 463. |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PLUG-01 | 02-01-PLAN.md | Plugin isolation test harness provides minimal ctx with declared dependencies only | SATISFIED | `plugin_harness.lua` `make_dep_enforced_services` proxy enforces declared deps. `plugin_harness_spec.lua` 7 test cases pass. Proxy only installed when `opts.allowed_deps` provided — backward compat maintained. |
| PLUG-02 | 02-01-PLAN.md | Canonical plugin example demonstrates component registration, system registration, and event handling | SATISFIED | `canonical_plugin.lua` demonstrates all four patterns: component fragments (`evolved.id`), system query (`evolved.builder`), event subscription (`ctx.bus:on`), service registration (`ctx.services:register`), plus config access (`ctx.config.tick_rate`). `canonical_plugin_spec.lua` 37 tests pass. |
| PLUG-03 | 02-02-PLAN.md | Architecture validator flags raw `evolved.spawn()` calls in plugin files | SATISFIED | `detect_raw_ecs_calls` flags direct `evolved.spawn()` calls and `local x = evolved.spawn` alias assignments as errors. `^src/plugins/` path guard correctly excludes `examples/`, `src/core/`, `lib/`. 6 tests confirm behavior. |
| PLUG-04 | 02-02-PLAN.md | Architecture validator flags `evolved.id()` calls in plugin files | SATISFIED | `detect_raw_ecs_calls` flags direct `evolved.id()` calls and `local x = evolved.id` alias assignments as errors. Separate test case `it("flags evolved.id() direct call as error")` at line 291. |
| PLUG-05 | 02-03-PLAN.md | Architecture validator cross-references `ctx.services:get()` against declared plugin deps | SATISFIED | `detect_undeclared_service_deps` reads `init.lua` for `MyPlugin.deps = { ... }` declaration, scans all `.lua` files under plugin dir for `services:get("X")` where X not in deps. Missing or unparseable deps declaration also flagged as CI-blocking error. 7 tests pass. |

**Orphaned requirements check:** REQUIREMENTS.md maps PLUG-01 through PLUG-05 to Phase 2 (lines 111-115). All 5 appear in plan frontmatter. No orphaned requirements.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `scripts/validate_architecture.lua` | 621 | `"Note: --fix is not yet implemented. Reporting violations only."` | Info | `--fix` is an optional convenience flag whose absence does not affect correctness. All 6 detection checks function fully. No impact on goal achievement. |

No TODO/FIXME/PLACEHOLDER/stub patterns found in any phase 2 artifacts. No empty implementations. No console.log-only handlers.

---

## Human Verification Required

None. All four success criteria are verifiable programmatically via code inspection and test file analysis. The test suite (229 tests per 02-03-SUMMARY.md) and `scripts/full-check.sh` pass on the clean project per SUMMARY self-checks.

---

## Gaps Summary

None. All 4 success criteria verified, all 5 requirements satisfied, all key links wired, no blocker anti-patterns found.

---

## Phase Goal Assessment

**Goal:** "The canonical plugin pattern is codified in a reference file and every plugin can be loaded and tested in isolation without sibling plugins"

Both halves are achieved:

1. **Codified reference file:** `examples/canonical_plugin.lua` demonstrates the complete canonical plugin pattern — config access, component fragments, ECS query construction, event subscription, service registration, and shutdown stub. The file is referenced in `CLAUDE.md` as the single source of truth.

2. **Isolation without sibling plugins:** `tests/helpers/plugin_harness.lua` provides a `create_context()` API that builds a real isolated context (real Bus, Worlds, Context — not stubs). The `allowed_deps` / `make_dep_enforced_services` proxy enforces that plugins cannot silently access services they have not declared, making dependency coupling a test-time failure rather than a runtime surprise.

The architecture validator (Checks 5 and 6) ensures the isolation contract is maintained as new plugins are written: raw ECS API calls bypass the isolation contract (PLUG-03/04), and undeclared service dependencies bypass the harness contract (PLUG-05).

---

_Verified: 2026-03-02_
_Verifier: Claude (gsd-verifier)_
