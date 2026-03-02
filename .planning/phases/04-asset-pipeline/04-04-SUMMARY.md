---
phase: 04-asset-pipeline
plan: "04"
subsystem: testing
tags: [busted, stdout, noise, print-stub, silent-mode, validator]

# Dependency graph
requires:
  - phase: 04-asset-pipeline
    provides: Asset plugin init.lua and boot manifest registration with load-then-pack pipeline

provides:
  - Silent busted test runs with zero extraneous stdout noise from harness, bus, or validator
  - Validator.run({ silent = true }) suppresses all internal print output
  - print stub pattern in tolerant-mode harness spec test

affects:
  - UAT-03 (clean busted output gate)
  - Future specs that test tolerant-mode plugins

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "_G.print stub in test body to suppress tolerant-mode warning output"
    - "opts.silent guard pattern via local log() helper in Validator.run()"

key-files:
  created: []
  modified:
    - tests/helpers/plugin_harness_spec.lua
    - tests/main_spec.lua
    - scripts/validate_architecture.lua

key-decisions:
  - "print stub uses _G.print assignment (save/restore) rather than spy — simpler and busted-agnostic"
  - "log() local helper inside Validator.run() avoids modifying print_section/print_warning_section signatures"
  - "if not silent guards wrap all six print_section/print_warning_section call sites — clean separation between library output and CLI output"
  - "Script entry point prints (lines 893-903) deliberately left unsuppressed — those are CLI output, not library output"

patterns-established:
  - "Tolerant-mode tests that trigger print warnings must stub _G.print before the triggering call and restore after"
  - "Library functions accepting opts tables should check opts.silent to suppress output when used programmatically"

requirements-completed:
  - ASST-01
  - ASST-02
  - ASST-03
  - ASST-04

# Metrics
duration: 2min
completed: 2026-03-02
---

# Phase 4 Plan 4: Stdout Noise Closure Summary

**Three targeted patches silence busted test stdout noise: print stub in harness spec tolerant test, log suppressor in Bus.new tolerant test, and opts.silent guard in Validator.run() covering all six print_section call sites.**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-02T19:43:21Z
- **Completed:** 2026-03-02T19:45:08Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- busted full suite (379 tests) runs with zero [Harness], [Bus], or "Fixed:" messages on stdout
- Validator.run({ silent = true }) produces exactly zero stdout lines, enabling clean programmatic use
- Validator.run() without silent still prints normally for CLI use
- All 379 existing tests continue to pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Stub print in harness spec and suppress Bus log in main_spec** - `044dda2` (fix)
2. **Task 2: Guard print calls behind opts.silent in validate_architecture.lua** - `83be07a` (fix)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `tests/helpers/plugin_harness_spec.lua` - Added _G.print stub/restore around tolerant-mode test body
- `tests/main_spec.lua` - Added log = function() end to Bus.new() in tolerant-mode config test
- `scripts/validate_architecture.lua` - Added silent local + log() helper in Validator.run(), wrapped all print_section/print_warning_section calls

## Decisions Made
- print stub uses _G.print save/restore rather than a busted spy — simpler, no spy cleanup needed, works outside busted spy lifecycle
- log() local helper inside Validator.run() avoids changing print_section/print_warning_section signatures (they remain unchanged for non-silent paths)
- if not silent guards wrap all six call sites rather than threading silent into print_section — preserves function signatures, keeps guard logic co-located with call sites
- Script entry-point prints deliberately left unsuppressed — those are CLI output, not library output

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 4 (Asset Pipeline) is now complete — all 4 plans executed
- busted output is clean for UAT-03 verification
- Validator silent mode enables safe programmatic use in test specs

---
*Phase: 04-asset-pipeline*
*Completed: 2026-03-02*

## Self-Check: PASSED

- tests/helpers/plugin_harness_spec.lua: FOUND
- tests/main_spec.lua: FOUND
- scripts/validate_architecture.lua: FOUND
- .planning/phases/04-asset-pipeline/04-04-SUMMARY.md: FOUND
- commit 044dda2: FOUND
- commit 83be07a: FOUND
