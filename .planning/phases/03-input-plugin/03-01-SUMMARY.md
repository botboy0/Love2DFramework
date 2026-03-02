---
phase: 03-input-plugin
plan: 01
subsystem: core-infrastructure
tags: [registry, update-loop, baton, input, lifecycle]

# Dependency graph
requires:
  - phase: 02-plugin-infrastructure
    provides: Registry with boot/shutdown lifecycle; plugin harness for tests

provides:
  - Registry:update_all(dt) per-frame plugin update lifecycle method
  - baton input library vendored at lib/baton.lua
  - main.lua wires update_all before bus:flush each frame

affects:
  - 03-02-input-plugin (uses update_all + baton)
  - Any future plugin needing per-frame updates

# Tech tracking
tech-stack:
  added: [baton (vendored at lib/baton.lua)]
  patterns:
    - TDD RED/GREEN for Registry lifecycle methods
    - Tolerant/strict error_mode symmetry in update loop matches boot loop pattern

key-files:
  created:
    - lib/baton.lua
  modified:
    - src/core/registry.lua
    - tests/core/registry_spec.lua
    - main.lua

key-decisions:
  - "update_all follows exact tolerant/strict pattern from boot() — pcall per plugin in tolerant, direct call in strict"
  - "update_all before boot() is a safe no-op — empty _boot_order means zero iterations"
  - "main.lua ordering: update_all(dt) -> receive_all -> bus:flush -> transport:flush — plugin updates emit events flushed same frame"

patterns-established:
  - "Registry lifecycle methods (boot/update_all/shutdown) share the same tolerant/strict error_mode structure"
  - "lib/ holds vendored libraries excluded from selene/stylua"

requirements-completed: [INPT-03]

# Metrics
duration: 2min
completed: 2026-03-02
---

# Phase 3 Plan 01: Registry update_all and baton vendor Summary

**Registry:update_all(dt) lifecycle added with tolerant/strict error_mode, baton input library vendored — prerequisites for input plugin**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-02T00:38:39Z
- **Completed:** 2026-03-02T00:40:50Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Registry:update_all(dt) implemented with full tolerant/strict error_mode support matching the boot() pattern
- 6 test cases added (TDD RED then GREEN) covering: update called, skip-without-method, dt passthrough, pre-boot no-op, tolerant logs+continues, strict propagates
- main.lua wired: update_all(dt) runs first in love.update before transport/bus, ensuring plugin-emitted events flush same frame
- baton v1.0.2 vendored at lib/baton.lua and verified loadable via require('lib.baton').new

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: failing update_all tests** - `9e2f689` (test)
2. **Task 1 GREEN: Registry:update_all + main.lua wiring** - `93e89ad` (feat)
3. **Task 2: vendor baton library** - `dda3ef3` (chore)

_Note: TDD task has two commits (test RED then feat GREEN)_

## Files Created/Modified
- `lib/baton.lua` - Vendored baton input library (374 lines, excluded from lint/format)
- `src/core/registry.lua` - Added Registry:update_all(dt) method (27 lines added)
- `tests/core/registry_spec.lua` - Added describe("update_all") block with 6 test cases
- `main.lua` - Added _registry:update_all(_dt) call as step 1 in love.update

## Decisions Made
- update_all follows the exact same tolerant/strict pcall pattern as boot() — symmetry makes the code predictable
- Pre-boot call is safe because _boot_order starts empty (not a guard branch, just natural loop behavior)
- main.lua ordering: update_all first so plugin-emitted events are flushed in the same frame (receive_all -> bus:flush -> transport:flush follow)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Stylua required breaking a long string.format() call across lines in update_all tolerant branch — auto-fixed inline before commit (Rule 3 - Blocking).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Registry:update_all(dt) ready for input plugin (03-02) to use
- baton vendored and loadable — input plugin can require('lib.baton')
- Full CI pipeline passes: selene, stylua, busted (235 tests), validate_architecture

## Self-Check: PASSED

- lib/baton.lua: FOUND
- Registry:update_all in src/core/registry.lua: FOUND
- update_all in main.lua: FOUND
- 03-01-SUMMARY.md: FOUND
- Commit 9e2f689 (test RED): FOUND
- Commit 93e89ad (feat GREEN + main.lua): FOUND
- Commit dda3ef3 (chore baton vendor): FOUND

---
*Phase: 03-input-plugin*
*Completed: 2026-03-02*
