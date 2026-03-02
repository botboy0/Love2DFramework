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
  - Validator.run({ log = function() end }) suppresses all internal print output
  - Harness create_context({ log = fn }) DI for tolerant-mode warning output

affects:
  - UAT-03 (clean busted output gate)
  - Future specs that test tolerant-mode plugins

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "log_fn DI parameter for output suppression (harness, validator, bus all use the same pattern)"

key-files:
  created: []
  modified:
    - tests/helpers/plugin_harness.lua
    - tests/helpers/plugin_harness_spec.lua
    - tests/main_spec.lua
    - scripts/validate_architecture.lua
    - tests/validate_architecture_spec.lua

key-decisions:
  - "All three noise sources use the same DI pattern: inject log_fn, default to print — consistent with Bus.new({ log = fn })"
  - "Harness accepts opts.log and passes it to dep enforcement proxy — no _G.print mutation needed"
  - "Validator passes log_fn through print_section/print_warning_section — no if-not-silent guards needed"
  - "Script entry point prints (lines 893-903) deliberately left unsuppressed — those are CLI output, not library output"

patterns-established:
  - "Suppress output via log_fn DI (pass log = function() end), never by mutating _G.print or boolean silent flags"

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

**Silences busted test stdout noise using consistent log_fn dependency injection across all three sources: harness (opts.log), Bus (opts.log — already existed), and validator (opts.log threaded through print_section/print_warning_section).**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-02T19:43:21Z
- **Completed:** 2026-03-02T19:45:08Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- busted full suite (379 tests) runs with zero [Harness], [Bus], or "Fixed:" messages on stdout
- All three noise sources use consistent log_fn DI pattern (matching Bus.new's existing approach)
- Validator.run({ log = function() end }) produces zero stdout lines; default print behavior unchanged
- Harness create_context({ log = fn }) injects logger into dep enforcement proxy — no global mutation
- All 379 existing tests continue to pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Stub print in harness spec and suppress Bus log in main_spec** - `044dda2` (fix)
2. **Task 2: Guard print calls behind opts.silent in validate_architecture.lua** - `83be07a` (fix)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `tests/helpers/plugin_harness.lua` - Added log_fn parameter to make_dep_enforced_services and opts.log passthrough in create_context
- `tests/helpers/plugin_harness_spec.lua` - Replaced _G.print stub with opts.log DI (log = function() end)
- `tests/main_spec.lua` - Added log = function() end to Bus.new() in tolerant-mode config test (unchanged from original 04-04)
- `scripts/validate_architecture.lua` - Added log_fn parameter to print_section/print_warning_section; Validator.run accepts opts.log; removed all if-not-silent guards
- `tests/validate_architecture_spec.lua` - Changed silent = true to log = function() end at all call sites

## Decisions Made
- All output suppression uses the same mechanism: inject a log function, default to print — this is the pattern Bus.new already established
- Harness dep enforcement proxy accepts log_fn — no _G.print mutation, no save/restore, no risk of leaked state on test failure
- Validator threads log_fn into print_section/print_warning_section — removes 6 copy-pasted if-not-silent guards, keeps the functions self-contained
- Script entry-point prints deliberately left unsuppressed — those are CLI output, not library output

## Revision History

### Rev 2 (2026-03-02) — Architectural consistency fix
The original 04-04 implementation used three inconsistent approaches to silence output:
1. _G.print global mutation in harness spec (violates DI pattern)
2. log = function() end in Bus.new (correct — uses existing DI)
3. if-not-silent boolean guards in validator (brute force, 6 copy-pasted guards)

Rev 2 unifies all three to use log_fn DI, matching the pattern Bus.new already established.
This also modifies plugin_harness.lua (the harness itself, not just the spec) to accept opts.log.

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
