---
phase: 02-plugin-infrastructure
plan: "02"
subsystem: testing
tags: [lua, validate_architecture, ecs, tdd, busted]

# Dependency graph
requires:
  - phase: 02-01
    provides: "Architecture validator baseline (detect_globals, detect_cross_plugin_imports, detect_logic_outside_ecs, detect_missing_tests)"
provides:
  - "detect_raw_ecs_calls function detecting evolved.spawn/id direct calls and aliases as errors"
  - "require('lib.evolved') in plugins detected as warning (not error)"
  - "Validator.run() dual return (error_count, warning_count)"
  - "format_verbose() helper showing rule reference + 3-line context for --verbose mode"
  - "print_warning_section() for [WARNING]-prefixed warning output"
  - "--verbose CLI flag threading through to per-violation output"
  - "Exit code 0 on warnings-only, exit 1 on errors (PLUG-03/04 enforcement)"
affects:
  - "03-plugin-infrastructure"
  - "CI pipeline (ci.yml) — validator exit code semantics now split errors/warnings"
  - "Any future plugin code using evolved.spawn/id directly"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "detect_*() functions return (errors, warnings) tables for checks with severity split"
    - "format_verbose() attaches _verbose_str to violations when verbose=true"
    - "Path guard pattern: return {}, {} immediately if path not ^src/plugins/"
    - "TDD: RED (failing tests) -> GREEN (minimal impl) -> verify full suite"

key-files:
  created: []
  modified:
    - "scripts/validate_architecture.lua"
    - "tests/validate_architecture_spec.lua"

key-decisions:
  - "detect_raw_ecs_calls uses ^src/plugins/ path guard — naturally excludes examples/, src/core/, lib/"
  - "Alias detection flags only the assignment line, not subsequent alias calls — avoids false positives with variable shadowing"
  - "evolved.spawn/id direct calls AND alias assignments are errors (CI-blocking); require('lib.evolved') is warning-only"
  - "Validator.run() now returns (error_count, warning_count) — breaking change from single total"
  - "format_verbose() stores _verbose_str on violation objects rather than reformatting at print time"
  - "Warning count printed as '(N warning(s))' before final pass/fail line in script output"

patterns-established:
  - "Severity split pattern: detect_* functions return two tables (errors, warnings) for checks with mixed severity"
  - "Verbose context: _verbose_str field on violations; print_section checks field before falling back to formatter"

requirements-completed: [PLUG-03, PLUG-04]

# Metrics
duration: 3min
completed: "2026-03-02"
---

# Phase 02 Plan 02: Raw ECS Call Detection Summary

**Architecture validator extended with evolved.spawn/id detection, error/warning severity split, verbose mode with CLAUDE.md rule references, and dual (error_count, warning_count) return from run().**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-02T00:13:30Z
- **Completed:** 2026-03-02T00:16:10Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `detect_raw_ecs_calls(path, lines)` flags `evolved.spawn()` and `evolved.id()` direct calls plus alias assignments as errors; `require("lib.evolved")` as warning only
- `Validator.run()` now returns `(error_count, warning_count)` — warnings don't block CI, errors do (exit code 1)
- `--verbose` flag shows CLAUDE.md rule reference and 3-line surrounding context for every violation
- All 222 project tests pass, validator exits 0 on clean project, linter/formatter clean

## Task Commits

Each task was committed atomically:

1. **Task 1: Add detect_raw_ecs_calls detection function** - `65d3af7` (feat)
2. **Task 2: Wire into run(), verbose mode, dual return, updated tests** - `73de799` (feat)

_Note: TDD tasks — RED (failing tests written first), then GREEN (implementation), then integration verified._

## Files Created/Modified

- `scripts/validate_architecture.lua` - Added `detect_raw_ecs_calls`, `format_verbose`, `print_warning_section`, updated `print_section` and `Validator.run()`, updated CLI entry point
- `tests/validate_architecture_spec.lua` - Added 11 tests for `detect_raw_ecs_calls`, updated `Validator.run` smoke test for dual return

## Decisions Made

- `detect_raw_ecs_calls` uses `^src/plugins/` path guard so examples/, src/core/, lib/ are naturally excluded without extra special-casing
- Alias detection (`local x = evolved.spawn`) flags only the assignment line to avoid false positives — subsequent calls via the alias are not tracked
- `format_verbose()` stores `_verbose_str` on violation objects when `opts.verbose=true` so print_section can use it without knowing about verbose mode
- `Validator.run()` dual return is a breaking change from the previous single `total`; integration smoke test updated accordingly

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Architecture validator now enforces PLUG-03 and PLUG-04: plugins cannot bypass the worlds API to call evolved directly
- Future plugin implementations in Phase 02 plan 03+ will be validated against raw ECS call rules automatically
- `--verbose` output is ready for developer workflow (can be added to CI failure output if desired)

---
*Phase: 02-plugin-infrastructure*
*Completed: 2026-03-02*
