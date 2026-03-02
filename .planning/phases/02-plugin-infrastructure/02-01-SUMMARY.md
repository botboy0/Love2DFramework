---
phase: 02-plugin-infrastructure
plan: 01
subsystem: testing
tags: [plugin-harness, canonical-plugin, dependency-enforcement, config-access]

# Dependency graph
requires:
  - phase: 01-core-infrastructure
    provides: Context.new(), Services registry, Bus, Worlds — all used by harness and canonical plugin
provides:
  - ctx.config access pattern codified in canonical_plugin.lua with tick_rate read and fallback
  - make_dep_enforced_services proxy in plugin_harness enforcing declared deps at test time
  - tests/helpers/plugin_harness_spec.lua with 7 test cases covering strict/tolerant/no-proxy modes
affects:
  - 02-plugin-infrastructure (remaining plans — harness is now dependency-enforcing)
  - all future plugins (canonical plugin is the reference template they follow)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - ctx.config access with default fallback (_tick_rate = ctx.config.tick_rate or 60)
    - Proxy table wrapping real_services via __index metatable
    - allowed_deps array + error_mode string as harness test options

key-files:
  created:
    - tests/helpers/plugin_harness_spec.lua
  modified:
    - examples/canonical_plugin.lua
    - tests/canonical_plugin_spec.lua
    - tests/helpers/plugin_harness.lua

key-decisions:
  - "Harness proxy intercepts :get() only; register() and all other methods delegate transparently to real services"
  - "error_mode defaults to 'strict' inline in harness — no shared resolve_error_mode helper (avoids third-caller duplication)"
  - "Proxy only installed when opts.allowed_deps is provided — backward compat for all existing harness usage"
  - "Canonical plugin keeps deps = {} empty — no fake dependency consumption in example (user decision from prior session)"

patterns-established:
  - "Plugin harness: pass allowed_deps = {'name'} to enforce isolation, error_mode = 'tolerant' to warn only"
  - "Config pattern: local _var = ctx.config.key or default — underscore prefix marks unused-in-example"

requirements-completed:
  - PLUG-01
  - PLUG-02

# Metrics
duration: 5min
completed: 2026-03-02
---

# Phase 2 Plan 1: Plugin Infrastructure — Canonical Plugin Config Access and Harness Dep Enforcement Summary

**ctx.config access pattern added to canonical plugin and services dependency proxy added to plugin harness, enforcing plugin isolation at test time with strict/tolerant modes**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-02T00:13:30Z
- **Completed:** 2026-03-02T00:18:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- canonical_plugin.lua now demonstrates config access: `local _tick_rate = ctx.config.tick_rate or 60`
- plugin_harness.lua now supports `opts.allowed_deps` and `opts.error_mode` for dependency enforcement
- `make_dep_enforced_services` proxy catches undeclared service access with clear error messages
- 7 new test cases in plugin_harness_spec.lua + 2 new config access tests in canonical_plugin_spec.lua

## Task Commits

Each task was committed atomically:

1. **Task 1: Add ctx.config usage to canonical plugin and harness dep enforcement proxy** - `b49e7f6` (feat)
2. **Task 2: Tests for canonical plugin config access and harness dep enforcement** - `1cf34ad` (test)

**Plan metadata:** TBD (docs: complete plan)

## Files Created/Modified
- `examples/canonical_plugin.lua` - Added config access comment block and _tick_rate read with default fallback in init()
- `tests/helpers/plugin_harness.lua` - Added make_dep_enforced_services() proxy; create_context now accepts allowed_deps and error_mode
- `tests/canonical_plugin_spec.lua` - Added describe("config access") with 2 tests for tick_rate and empty config
- `tests/helpers/plugin_harness_spec.lua` - NEW: 7 test cases covering ctx shape, dep pre-registration, strict/tolerant/no-proxy modes and register() delegation

## Decisions Made
- Harness proxy intercepts `:get()` only; `register()` and all other methods delegate transparently to real services via `__index` fallback
- `error_mode` defaults to `"strict"` inline in harness — avoids pulling in `resolve_error_mode` from context.lua (no third caller yet)
- Proxy only installed when `opts.allowed_deps` is provided — all existing harness callers are unaffected
- Canonical plugin keeps `deps = {}` empty — no fake dependency consumption in example (user decision from prior session)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plugin harness now enforces declared dependencies — remaining phase 2 plans can use `allowed_deps` in tests
- Canonical plugin is the reference template for all game plugins; config pattern is now part of that reference
- No blockers for 02-02 onward

## Self-Check: PASSED

All files found. All commits verified.

---
*Phase: 02-plugin-infrastructure*
*Completed: 2026-03-02*
