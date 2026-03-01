---
phase: 01-core-infrastructure
plan: "04"
subsystem: infra
tags: [love2d, lua, ecs, evolved, transport, registry, bus, canonical-plugin]

# Dependency graph
requires:
  - phase: 01-03
    provides: Context transport wiring, Registry error_mode and side enforcement
  - phase: 01-02
    provides: Bus deferred-dispatch with error modes, Transport with NullTransport stub
  - phase: 01-01
    provides: Worlds single/dual-world, plugin harness, components.lua empty contract

provides:
  - love.quit lifecycle hook calling registry:shutdown(ctx) in reverse boot order
  - Transport flush ordering in love.update (receive_all -> bus:flush -> transport:flush)
  - Config (_config) threaded to Bus.new, Registry.new, and Context.new
  - canonical_plugin.lua working in single-world mode with local fragment definitions
  - Full CI green (lint, format, tests, architecture validator)

affects: [all future phases, plugin authors, game entry point setup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - love.quit guard pattern (if _registry and _ctx then)
    - Transport flush ordering (inbound receive -> bus flush -> outbound flush)
    - Canonical plugin single-world compatibility via conditional server.tag inclusion

key-files:
  created:
    - tests/main_spec.lua (love.quit, update ordering, config threading tests)
  modified:
    - main.lua (love.quit, transport flush, config threading)
    - examples/canonical_plugin.lua (single-world mode, local fragments)
    - tests/canonical_plugin_spec.lua (single-world mode tests added)

key-decisions:
  - "love.quit guard: if _registry and _ctx before calling shutdown — safe for quit-before-load"
  - "Transport flush ordering: receive_all first so inbound messages are in bus queue before flush delivers them"
  - "_config local in main.lua — games override here or in conf.lua; not loaded from file"
  - "canonical_plugin.lua uses local ExPosition/ExVelocity fragments (not Components module) since components.lua is empty"
  - "Single-world query: build without server.tag when ctx.worlds.server is nil — duck-type check"

patterns-established:
  - "Pattern 1: love.quit guard — if _registry and _ctx then shutdown"
  - "Pattern 2: Game loop order — transport:receive_all, bus:flush, transport:flush per tick"
  - "Pattern 3: Config threading — _config passes through Bus.new, Registry.new, Context.new"
  - "Pattern 4: Single-world compatibility — check ctx.worlds.server before including world tag in query"

requirements-completed: [CORE-01, CORE-02, CORE-07, CORE-10]

# Metrics
duration: 3min
completed: 2026-03-02
---

# Phase 1 Plan 4: Main.lua Integration and Canonical Plugin Summary

**Love2D entry point fully wired: love.quit shutdown lifecycle, transport flush ordering (receive_all->bus->transport), config threading, and canonical_plugin.lua updated for single-world mode with local evolved fragments**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-02T23:14:41Z
- **Completed:** 2026-03-02T23:17:26Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Added `love.quit()` that calls `_registry:shutdown(_ctx)` when both non-nil, with nil safety for quit-before-load
- Implemented correct transport flush ordering in `love.update`: `receive_all` queues inbound messages as bus events, then `bus:flush` delivers all events, then `transport:flush` sends outbound
- Threaded `_config` through to `Bus.new`, `Registry.new`, and `Context.new` so error_mode and transport options flow from a single config table
- Updated `canonical_plugin.lua` to work in single-world mode by conditionally including `server.tag` only when `ctx.worlds.server` exists
- Full CI pipeline passes: selene lint, stylua format, busted tests (202 passing), architecture validator

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire main.lua with love.quit, config threading, and transport flush** - `57d2ad8` (feat)
2. **Task 2: Update canonical_plugin.lua for empty components.lua and run full CI** - `69f4441` (feat)

## Files Created/Modified
- `main.lua` - Added love.quit, transport flush ordering, config threading via _config
- `tests/main_spec.lua` - Full test coverage for quit lifecycle, update ordering, config threading
- `examples/canonical_plugin.lua` - Single-world mode support, conditional server.tag inclusion
- `tests/canonical_plugin_spec.lua` - Added single-world init and update tests

## Decisions Made
- `love.quit` guard uses `if _registry and _ctx` short-circuit — safe for applications that quit before `love.load` completes
- Transport receive happens before bus flush so inbound network messages are already in the bus queue when flush delivers them this tick
- `_config` is a plain local table in `main.lua` — game developers override here or in `conf.lua`
- `canonical_plugin.lua` keeps `CanonicalPlugin.Position` and `CanonicalPlugin.Velocity` on the module table so specs can reference them without importing a separate components module
- Single-world compatibility uses `if ctx.worlds.server then` duck-type check — consistent with the established dual-world detection pattern

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

**canonical_plugin_spec.lua single-world test:** Initial attempt to spawn an entity using `evolved.defer()` directly (treating its return value as an entity ID) failed because `evolved.defer()` returns a boolean. Fixed immediately by using `single_ctx.worlds:spawn({...})` which is the correct API for single-world mode. This was caught in the RED-then-GREEN TDD cycle.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 1 Core Infrastructure is complete. All 10 CORE requirements (CORE-01 through CORE-10) have been addressed across Plans 01-04:
- Worlds (single/dual), Bus (deferred events, error modes), Transport (NullTransport, real transport)
- Context (injection point), Registry (topo sort, boot/shutdown), main.lua (full game loop)
- Canonical plugin (reference implementation, single + dual world modes)
- Full CI pipeline operational (lint, format, test, architecture validator)

Phase 2 can begin. The framework's core infrastructure is established and tested.

## Self-Check: PASSED

- FOUND: main.lua
- FOUND: examples/canonical_plugin.lua
- FOUND: tests/main_spec.lua
- FOUND: tests/canonical_plugin_spec.lua
- FOUND: .planning/phases/01-core-infrastructure/01-04-SUMMARY.md
- FOUND commit: 57d2ad8
- FOUND commit: 69f4441

---
*Phase: 01-core-infrastructure*
*Completed: 2026-03-02*
