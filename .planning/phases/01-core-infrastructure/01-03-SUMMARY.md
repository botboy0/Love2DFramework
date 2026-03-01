---
phase: 01-core-infrastructure
plan: 03
subsystem: core
tags: [lua, love2d, ecs, transport, bus, registry, context, error-handling, dual-world]

# Dependency graph
requires:
  - phase: 01-01
    provides: "Worlds.create() single-world and dual-world API"
  - phase: 01-02
    provides: "Bus.new() with error_mode and Transport with NullTransport"
provides:
  - "Context.new() with transport field always present (NullTransport or real)"
  - "Auto-bridge: bus:emit() transparently queues networkable events to transport"
  - "transport = true shorthand with transport_channels for framework-managed transport"
  - "Registry.new() with error_mode (strict/tolerant) and opts.log support"
  - "Registry tolerant mode: plugin init errors logged, boot continues, failed plugins excluded from shutdown"
  - "Registry side enforcement: cross-side deps rejected in dual-world mode, ignored in single-world"
affects:
  - 01-04-main
  - all-plugins
  - dual-world-features

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "resolve_error_mode(config, module_name, fallback) — module-specific error mode resolution from config"
    - "Auto-bridge pattern: wrap bus:emit() to forward networkable events to transport transparently"
    - "NullTransport-always pattern: ctx.transport is always present, callers never guard with 'if ctx.transport'"
    - "Duck-type transport check: table with mark_networkable method treated as valid transport instance"
    - "Tolerant boot pattern: pcall(entry.module.init, entry.module, ctx) with log on failure"
    - "Side enforcement via is_dual_world() duck-type check on ctx.worlds"

key-files:
  created: []
  modified:
    - "src/core/context.lua — Transport require, resolve_transport(), install_auto_bridge(), transport field on ctx"
    - "src/core/registry.lua — resolve_error_mode(), opts in Registry.new(), side field in register(), tolerant boot, side enforcement in validate_deps()"
    - "tests/core/context_spec.lua — transport wiring tests, auto-bridge tests, config passthrough tests"
    - "tests/core/registry_spec.lua — error_mode tests (strict/tolerant), side enforcement tests (dual/single world)"

key-decisions:
  - "Always install auto-bridge: NullTransport.is_networkable always returns false, so queue is never called — no special-casing needed"
  - "transport = true requires opts.transport_channels = { outbound, inbound } — main.lua resolves channel creation, Context assembles"
  - "resolve_error_mode duplicated in context.lua and registry.lua (5 lines) — acceptable until a shared util is warranted"
  - "Registry tolerant mode uses pcall(entry.module.init, entry.module, ctx) not entry.module:init(ctx) to correctly capture errors"
  - "Side enforcement uses is_dual_world() duck-type check (worlds.server and worlds.client both present) — no flag needed"

patterns-established:
  - "resolve_error_mode(config, module_name, fallback): check config.error_modes[module_name] first, then config.error_mode, then fallback"
  - "NullTransport-always: ctx.transport is never nil after Context.new() — all plugins can call transport methods unconditionally"

requirements-completed: [CORE-01, CORE-02, CORE-07, CORE-09]

# Metrics
duration: ~4min
completed: 2026-03-02
---

# Phase 1 Plan 03: Context and Registry Wiring Summary

**Context wired with NullTransport-always pattern and auto-bridge; Registry gains error_mode (strict/tolerant) and dual-world side enforcement**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-01T23:08:29Z
- **Completed:** 2026-03-02T23:12:06Z
- **Tasks:** 2 (each with TDD RED + GREEN commits)
- **Files modified:** 4

## Accomplishments

- Context.new() always produces a ctx.transport (NullTransport when disabled, real Transport when provided or created via transport = true)
- Auto-bridge installed on bus:emit() transparently queues networkable events to transport — callers see no difference
- Registry.new() accepts config for error_mode resolution; tolerant mode logs plugin init failures and continues booting remaining plugins
- Failed plugins in tolerant mode are excluded from _boot_order so they are not called during shutdown
- Side enforcement validates cross-side dependencies in dual-world mode; single-world ignores side declarations entirely

## Task Commits

Each task was committed atomically using TDD:

1. **Task 1 RED: failing tests for transport wiring and auto-bridge** - `a9c7e89` (test)
2. **Task 1 GREEN: Context wired with transport and auto-bridge** - `7fb560d` (feat)
3. **Task 2 RED: failing tests for registry error_mode and side enforcement** - `debc77f` (test)
4. **Task 2 GREEN: Registry with error_mode and side enforcement** - `9346ce6` (feat)

## Files Created/Modified

- `/mnt/c/Users/Trynda/Desktop/Dev/Lua/Love2D/Love2DFramework/src/core/context.lua` — Added Transport require, resolve_transport(), install_auto_bridge(), and transport field on returned ctx
- `/mnt/c/Users/Trynda/Desktop/Dev/Lua/Love2D/Love2DFramework/src/core/registry.lua` — Added resolve_error_mode(), opts in Registry.new(), side field in register(), tolerant boot via pcall, side enforcement in validate_deps()
- `/mnt/c/Users/Trynda/Desktop/Dev/Lua/Love2D/Love2DFramework/tests/core/context_spec.lua` — Added transport wiring tests (null/false/true/instance), auto-bridge tests (networkable/non-networkable), config passthrough tests
- `/mnt/c/Users/Trynda/Desktop/Dev/Lua/Love2D/Love2DFramework/tests/core/registry_spec.lua` — Added error_mode tests (strict propagates, tolerant logs+continues, failed excluded from shutdown), side enforcement tests (dual/single world)

## Decisions Made

- **Always install auto-bridge:** NullTransport.is_networkable always returns false so transport:queue is never reached. No conditional bridge installation needed — the bridge is always present and safe.
- **transport = true requires opts.transport_channels:** The plan considered auto-creating channels inside Context.new, but channel creation belongs in main.lua. Context receives channels and creates Transport, or receives a pre-built Transport instance.
- **resolve_error_mode duplicated:** The 5-line helper is duplicated in context.lua and registry.lua rather than extracted to a shared util. Acceptable until a third caller appears.
- **Tolerant boot uses pcall(entry.module.init, entry.module, ctx):** Method-call syntax entry.module:init(ctx) cannot be pcall'd cleanly — explicit self passing is required to capture the error correctly.
- **is_dual_world() duck-type check:** Checks ctx.worlds.server and ctx.worlds.client both exist — no worlds mode flag needed; the shape of the worlds handle tells us the mode.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Context assembly is complete: worlds + bus + transport + services + config all wired
- Registry is production-ready: strict mode for dev, tolerant mode for resilient production boot, side enforcement for dual-world plugin isolation
- Plan 01-04 (main.lua wiring) can now call Context.new() and Registry.new() with full config support
- All 188 tests pass with no regressions from Plans 01-01 and 01-02

---
*Phase: 01-core-infrastructure*
*Completed: 2026-03-02*
