---
phase: 01-core-infrastructure
plan: "02"
subsystem: core
tags: [lua, love2d, event-bus, transport, error-mode, null-object, busted]

requires:
  - phase: 01-core-infrastructure/01-01
    provides: Base Bus and Transport modules that this plan extends

provides:
  - Bus error_mode support (strict and tolerant) with backward compat
  - Transport.Null null-object stub implementing full Transport API
  - 55 passing tests covering all error_mode paths and NullTransport methods

affects:
  - All future plugins that use ctx.bus (now have strict mode option for dev)
  - All future plugins that use ctx.transport (now always present via NullTransport)
  - Plugin registry / ctx construction (should wire Transport.Null when transport disabled)

tech-stack:
  added: []
  patterns:
    - "error_mode pattern: Bus accepts opts table with error_mode field; function arg treated as log for backward compat"
    - "Null-object pattern: Transport.Null implements full Transport interface as no-ops so callers never need nil guards"
    - "Strict/tolerant duality: pcall + re-raise pattern resets _flushing before error propagates in strict mode"

key-files:
  created: []
  modified:
    - src/core/bus.lua
    - src/core/transport.lua
    - tests/core/bus_spec.lua
    - tests/core/transport_spec.lua

key-decisions:
  - "Bus strict mode uses pcall + error(err, 0) re-raise (not bare call) so _flushing flag is always reset before error propagates"
  - "Bus.new(fn) backward compat: function arg is treated as log with tolerant mode; opts table is the new preferred form"
  - "Transport.Null exposed as Transport.Null (not a separate module) so callers require only src.core.transport"

patterns-established:
  - "Null-object: always provide a null stub so ctx fields are never nil — eliminates nil-guard boilerplate in plugins"
  - "Error mode: accept opts table with error_mode field; default to tolerant; strict for dev/CI"

requirements-completed: [CORE-03, CORE-04, CORE-09]

duration: 2min
completed: 2026-03-01
---

# Phase 1 Plan 02: Bus error_mode and NullTransport Summary

**Bus upgraded with strict/tolerant error_mode selection; Transport.Null null-object stub added so ctx.transport is always present without nil guards**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-01T23:00:10Z
- **Completed:** 2026-03-01T23:02:12Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Bus.new() now accepts opts table with error_mode ("strict" or "tolerant"); backward compat for Bus.new(fn) preserved
- Tolerant mode (default): handler errors caught, logged, remaining handlers continue — existing behavior unchanged
- Strict mode: handler error re-raised from flush() via pcall + error(err, 0) so _flushing is always reset before error propagates
- Transport.Null added as a null-object transport — all methods are no-ops, is_networkable() returns false, receive_all() returns {}
- 55 tests passing: 26 bus_spec (including 8 new error_mode tests) + 29 transport_spec (including 8 new NullTransport tests)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add error_mode support to Bus** - `ff6205f` (feat)
2. **Task 2: Add NullTransport stub to Transport module** - `7765546` (feat)

**Plan metadata:** (docs commit follows)

_Note: Both tasks used TDD — tests written first (RED), then implementation (GREEN), then stylua format pass._

## Files Created/Modified

- `src/core/bus.lua` - Added opts table constructor, _error_mode field, strict/tolerant dispatch in flush()
- `tests/core/bus_spec.lua` - Added error_mode describe block with 8 new tests
- `src/core/transport.lua` - Added NullTransport class exposed as Transport.Null
- `tests/core/transport_spec.lua` - Added NullTransport describe block with 8 new tests

## Decisions Made

- **pcall + re-raise pattern for strict mode:** We still use pcall in strict mode so we can reset `_flushing = false` before calling `error(err, 0)`. A bare call would leave `_flushing = true` if the handler errors, permanently blocking the bus.
- **Backward compat via type check:** `if type(opts) == "function"` detects the old Bus.new(log_fn) call pattern. This avoids a breaking change for any existing callers.
- **Transport.Null on the Transport table (not a separate module):** Keeps the API surface minimal — callers require only `src.core.transport` and access `Transport.Null.new()` from the same table.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Bus and Transport modules are complete with error_mode and null-object support
- Plugin registry (01-03) can now wire `ctx.transport = Transport.Null.new()` when transport is disabled
- Plugins can safely use `ctx.bus` with strict mode in development and tolerant in release
- All selene lint and stylua format checks pass on both modified files

## Self-Check: PASSED

- src/core/bus.lua: FOUND
- src/core/transport.lua: FOUND
- tests/core/bus_spec.lua: FOUND
- tests/core/transport_spec.lua: FOUND
- .planning/phases/01-core-infrastructure/01-02-SUMMARY.md: FOUND
- Commit ff6205f (Task 1): FOUND
- Commit 7765546 (Task 2): FOUND
- 55 tests passing: VERIFIED

---
*Phase: 01-core-infrastructure*
*Completed: 2026-03-01*
