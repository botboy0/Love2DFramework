---
phase: 02-plugin-infrastructure
plan: "03"
subsystem: testing
tags: [lua, validate_architecture, ecs, tdd, busted, service-deps]

# Dependency graph
requires:
  - phase: 02-02
    provides: "detect_raw_ecs_calls, format_verbose, print_warning_section, Validator.run() dual return"
provides:
  - "parse_declared_deps(lines) local helper — parses single-line MyPlugin.deps = { ... } declarations"
  - "Validator.detect_undeclared_service_deps(plugin_dir) — cross-references init.lua deps against services:get() calls in all plugin files"
  - "Check 6 in Validator.run() — undeclared service deps and missing deps declarations are CI-blocking errors"
  - "Print sections: 'Undeclared Service Dependencies' and 'Missing deps Declaration'"
  - "Verbose mode support for service dep violations (format_verbose with CLAUDE.md SS4 rule ref)"
affects:
  - "04-plugin-infrastructure"
  - "CI pipeline — plugins must now declare all services:get() targets in MyPlugin.deps"
  - "Any future plugin using ctx.services:get() without declared deps"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-line deps convention enforced: MyPlugin.deps = { 'dep1', 'dep2' } parsed by regex"
    - "detect_undeclared_service_deps takes plugin_dir (not path) — needs cross-file cross-reference"
    - "Two error tables returned: errors (undeclared calls) + dep_parse_errors (structural violations)"
    - "Plugin dir deduplication in run() via seen-set before iterating"

key-files:
  created: []
  modified:
    - "scripts/validate_architecture.lua"
    - "tests/validate_architecture_spec.lua"

key-decisions:
  - "parse_declared_deps local (not Validator.): only detect_undeclared_service_deps needs it; no external callers"
  - "detect_undeclared_service_deps takes plugin_dir not individual file — must cross-reference init.lua deps against all files"
  - "Missing init.lua returns dep_parse_error not error — structural violation, not a service dep violation"
  - "Unparseable deps (no single-line declaration) returns dep_parse_error with guidance message"
  - "Both error tables (service dep errors + dep parse errors) counted as errors in run() — both CI-blocking"
  - "Plugin dir deduplication uses seen-set in run() to avoid double-counting multi-file plugins"

patterns-established:
  - "Cross-file validation pattern: detect_* functions that need cross-file context take a directory, not individual paths"
  - "Two-table return for structural vs content violations: (errors, dep_parse_errors)"

requirements-completed: [PLUG-05]

# Metrics
duration: 5min
completed: "2026-03-02"
---

# Phase 02 Plan 03: Undeclared Service Dependency Detection Summary

**Architecture validator extended with services:get() dependency enforcement — plugins must declare all consumed services in a single-line MyPlugin.deps = { ... } or face CI-blocking errors.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-02T00:18:57Z
- **Completed:** 2026-03-02T00:24:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `parse_declared_deps(lines)` parses `MyPlugin.deps = { 'a', 'b' }` single-line declarations; handles empty, trailing commas, both quote styles; returns nil if no declaration found
- `Validator.detect_undeclared_service_deps(plugin_dir)` reads init.lua deps, scans all .lua files under the plugin dir for `services:get("X")` calls not in declared deps, returns `(errors, dep_parse_errors)`
- Check 6 wired into `Validator.run()`: deduplicates plugin dirs, runs detection on each, counts both error types as CI-blocking
- 7 new TDD tests covering: undeclared call detection, declared call allowed, missing deps declaration, empty deps, subdirectory scanning, both quote styles, missing init.lua
- All 229 project tests pass, validator exits 0 on clean project, `scripts/full-check.sh` passes

## Task Commits

Each task was committed atomically:

1. **Task 1: Add parse_declared_deps and detect_undeclared_service_deps** - `625bde1` (feat)
2. **Task 2: Wire into Validator.run()** - `90352c4` (feat)

_Note: TDD tasks — RED (7 failing tests written first), then GREEN (implementation), then integration verified._

## Files Created/Modified

- `scripts/validate_architecture.lua` - Added `parse_declared_deps` local helper, `Validator.detect_undeclared_service_deps()`, Check 6 in `Validator.run()` with verbose mode support
- `tests/validate_architecture_spec.lua` - Added `describe("Validator.detect_undeclared_service_deps", ...)` with 7 tests covering all detection scenarios

## Decisions Made

- `parse_declared_deps` is local (not on Validator table) because only `detect_undeclared_service_deps` calls it — no external callers warranted
- `detect_undeclared_service_deps` takes `plugin_dir` (whole directory) rather than individual files — cross-file context is fundamental: init.lua declares deps, other files use services
- Missing init.lua and missing/unparseable deps declaration both produce `dep_parse_errors` (structural violations distinct from content violations)
- Both error tables counted as CI-blocking errors in `run()` — missing deps declaration is as bad as an undeclared call
- Plugin directory deduplication uses a seen-set (`plugin_dirs_seen`) to avoid running the check twice on multi-file plugins

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Validator now enforces PLUG-05: plugins cannot silently depend on services they haven't declared
- Full checks pass — ready for Phase 02 Plan 04
- Service dep enforcement is active for any plugins added in subsequent phases

## Self-Check: PASSED

- FOUND: scripts/validate_architecture.lua
- FOUND: tests/validate_architecture_spec.lua
- FOUND: .planning/phases/02-plugin-infrastructure/02-03-SUMMARY.md
- FOUND commit 625bde1 (feat(02-03): add parse_declared_deps and detect_undeclared_service_deps)
- FOUND commit 90352c4 (feat(02-03): wire detect_undeclared_service_deps into Validator.run())
- 229 tests pass, validator exits 0 on clean project, full-check.sh passes

---
*Phase: 02-plugin-infrastructure*
*Completed: 2026-03-02*
