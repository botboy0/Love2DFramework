---
phase: 02-core-infrastructure
plan: 01
subsystem: infra
tags: [evolved.lua, binser, event-bus, ecs, lua, tdd, busted]

# Dependency graph
requires: []
provides:
  - "lib/evolved.lua: vendored ECS library for entity-component-system architecture"
  - "lib/binser.lua: vendored serialization library for save/load and networking"
  - "src/core/bus.lua: deferred-dispatch event bus with re-entrancy guard, error isolation, and injectable logger"
  - "tests/core/bus_spec.lua: 17-test suite covering all bus behaviors"
affects:
  - 02-core-infrastructure
  - all plugin plans (every plugin uses the event bus for inter-system communication)

# Tech tracking
tech-stack:
  added:
    - "evolved.lua (BlackMATov/evolved.lua, main branch) — ECS library"
    - "binser (bakpakin/binser, master branch) — Lua serialization"
  patterns:
    - "Deferred-dispatch event bus: emit() queues, flush() dispatches — prevents re-entrancy mid-tick"
    - "Injectable logger pattern: Bus.new(log_fn) defaults to print, allows test injection without global override"
    - "TDD RED-GREEN: tests written before implementation, all 17 pass green"

key-files:
  created:
    - lib/evolved.lua
    - lib/binser.lua
    - src/core/bus.lua
    - tests/core/bus_spec.lua
  modified: []

key-decisions:
  - "Injectable logger: Bus.new(log) accepts optional log function (default: print) — allows test capture without overriding print global (selene denies global reassignment)"
  - "Queue snapshot in flush(): self._queue replaced with {} before dispatch — illegal emits during flush see empty queue cleanly"
  - "pcall per handler: each handler wrapped individually so one error does not abort remaining handlers"
  - "No priority levels: registration order only, as specified in CONTEXT.md"
  - "No wildcard subscriptions: exact event name matching only"

patterns-established:
  - "Event bus logger injection: Bus.new(log_fn) pattern for testability without global mutation"
  - "Deferred dispatch: all systems emit then flush at end of tick"

requirements-completed:
  - INFRA-01

# Metrics
duration: 2min
completed: 2026-03-01
---

# Phase 2 Plan 01: Vendor Libraries and Event Bus Summary

**Deferred-dispatch event bus with re-entrancy guard and injectable logger, plus evolved.lua and binser vendored into lib/**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-01T18:45:19Z
- **Completed:** 2026-03-01T18:47:34Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Vendored evolved.lua (7,915 lines) and binser (753 lines) into lib/ — excluded from selene/stylua
- Implemented deferred-dispatch event bus: emit() queues events, flush() dispatches in emit order
- Re-entrancy guard prevents handlers from emitting during flush (logs warning, discards event)
- Handler errors caught with pcall — logged with event name and error message, remaining handlers continue
- 17 tests pass covering all specified behaviors (deferred dispatch, ordering, error isolation, sub/unsub)

## Task Commits

Each task was committed atomically:

1. **Task 1: Vendor evolved.lua and binser libraries** - `e330f86` (chore)
2. **Task 2: RED — failing bus tests** - `c79764d` (test)
3. **Task 2: GREEN — implement bus** - `63619a0` (feat)

_Note: TDD task has two commits (test RED, feat GREEN). No refactor needed._

## Files Created/Modified

- `lib/evolved.lua` — Vendored ECS library (BlackMATov/evolved.lua, main branch)
- `lib/binser.lua` — Vendored serialization library (bakpakin/binser, master branch)
- `src/core/bus.lua` — Deferred-dispatch event bus implementation (97 lines)
- `tests/core/bus_spec.lua` — Event bus test suite, 17 tests (224 lines)

## Decisions Made

- **Injectable logger:** `Bus.new(log_fn)` accepts optional log function defaulting to `print`. This allows tests to inject a spy function and capture log output without reassigning the `print` global (which selene denies as `incorrect_standard_library_use`). The bus API is unchanged for production callers.
- **Queue snapshot in flush:** During flush, `self._queue` is replaced with a fresh empty table before dispatch begins. This means any (illegal) emit calls during flush check the re-entrancy guard first, and if they somehow bypass it, they'd push to the new queue. The guard prevents this, but the snapshot ensures clean isolation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Injectable logger instead of direct print override in tests**
- **Found during:** Task 2, RED phase (first commit attempt)
- **Issue:** Initial test implementation overrode `print` global (`print = function(...)`) to capture log output. Pre-commit hook ran selene, which rejected this with `incorrect_standard_library_use` — standard library globals are not overridable in selene's model.
- **Fix:** Changed `Bus.new()` to accept an optional `log` parameter (default: `print`). Tests inject a spy function `Bus.new(function(msg) ... end)`. Production callers call `Bus.new()` unchanged.
- **Files modified:** `tests/core/bus_spec.lua`, `src/core/bus.lua`
- **Verification:** Pre-commit passes, all 17 tests pass, selene reports 0 errors on bus.lua
- **Committed in:** c79764d (RED test commit), 63619a0 (GREEN impl commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — selene compliance)
**Impact on plan:** Auto-fix improves testability and API flexibility. No scope creep — same observable behavior.

## Issues Encountered

None beyond the selene deviation above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- evolved.lua available for plugin plans that wire up ECS world
- binser available for serialization (save/load, network transport)
- Event bus is the communication backbone — all subsequent plugin plans can call `bus:on()`, `bus:emit()`, `bus:flush()`
- No blockers for 02-02 (plugin registry) or subsequent plans

## Self-Check: PASSED

All files confirmed present on disk. All commits confirmed in git history.
