---
phase: 01-core-infrastructure
plan: 01
subsystem: ecs
tags: [love2d, lua, evolved-lua, ecs, worlds, components]

requires: []

provides:
  - Single-world mode for Worlds.create() (default, no tags)
  - Dual-world mode for Worlds.create({ dual = true }) (opt-in, ServerTag/ClientTag)
  - Empty components.lua — framework is now genre-agnostic, games define own fragments
  - Clear error messages when spawn mode is mismatched

affects:
  - 01-02 (bus/transport — these use Worlds in integration)
  - all future plugins (plugin_harness now uses dual-world by default)
  - examples/canonical_plugin.lua (updated to use own fragment IDs)

tech-stack:
  added: []
  patterns:
    - "Worlds.create() defaults to single-world; dual-world is explicit opt-in via { dual = true }"
    - "Components.lua ships empty; games define fragment IDs in that file"
    - "Canonical plugin exposes its fragment IDs on the module table for testability"

key-files:
  created: []
  modified:
    - src/core/worlds.lua
    - src/core/components.lua
    - tests/core/worlds_spec.lua
    - tests/core/components_spec.lua
    - tests/helpers/plugin_harness.lua
    - tests/core/context_spec.lua
    - tests/canonical_plugin_spec.lua
    - examples/canonical_plugin.lua

key-decisions:
  - "Single-world is the default (no opts arg) — minimal onboarding for games without client/server separation"
  - "Dual-world is opt-in via { dual = true } — preserves tag-isolation behavior for server/client games"
  - "components.lua ships with return {} — zero pre-defined fragments; framework is genre-agnostic"
  - "canonical_plugin.lua exposes Position/Velocity on module table so tests can spawn matching entities without importing a now-empty components.lua"

patterns-established:
  - "Mode-guard errors: each spawn method errors immediately if called in the wrong mode with a message naming the mode and suggesting the correct method"
  - "Fragment ownership: example/reference plugins define their own fragment IDs locally rather than importing from components.lua"

requirements-completed:
  - CORE-05
  - CORE-06
  - CORE-08

duration: 5min
completed: 2026-03-01
---

# Phase 1 Plan 01: Worlds Single-World Mode + Empty Components Summary

**Worlds.create() now defaults to single-world mode (no tag isolation); dual-world (ServerTag/ClientTag) is explicit opt-in; components.lua ships as an empty registry so the framework is genre-agnostic**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-01T23:00:13Z
- **Completed:** 2026-03-01T23:05:47Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- `Worlds.create()` with no args returns a single-world handle where `spawn()` works and `spawn_server()`/`spawn_client()` error with descriptive "single-world" messages
- `Worlds.create({ dual = true })` returns a dual-world handle with existing tag-isolation behavior; `spawn()` now errors with a "dual-world" hint pointing to the correct methods
- `components.lua` replaced with `return {}` — zero pre-defined fragment IDs, making the framework genre-agnostic
- Fixed all callers of the old `Worlds.create()` API that expected dual-world behavior by default (plugin_harness, context_spec, canonical_plugin and its spec)

## Task Commits

Each task was committed atomically:

1. **Task 1: Single-world mode + dual-world opt-in** - `48a5af0` (feat)
2. **Task 2: Empty components.lua** - `8e3ea0c` (feat)
3. **Rule 1 auto-fix: update API callers** - `e44d124` (fix)

_Note: TDD tasks have test-then-impl structure baked into each task commit_

## Files Created/Modified

- `src/core/worlds.lua` - Single-world default, dual-world opt-in, mode-guard errors on wrong spawn method
- `src/core/components.lua` - Replaced with empty registry (`return {}`)
- `tests/core/worlds_spec.lua` - Restructured into single-world and dual-world describe blocks (28 tests)
- `tests/core/components_spec.lua` - Updated to assert table type and emptiness; removed fragment field assertions
- `tests/helpers/plugin_harness.lua` - Changed to `Worlds.create({ dual = true })` for tests needing server/client
- `tests/core/context_spec.lua` - Two tests updated to use dual-world where server/client access is asserted
- `tests/canonical_plugin_spec.lua` - Removed Components import; uses `CanonicalPlugin.Position/Velocity` for entity spawning
- `examples/canonical_plugin.lua` - Removed Components import; defines own fragment IDs, exposes them on module table

## Decisions Made

- **Single-world as default:** Games that don't need client/server separation should not pay the cognitive cost of learning tag isolation. `Worlds.create()` with no args is the minimal onboarding path.
- **Dual-world as opt-in:** Existing dual-world behavior is preserved exactly; callers just add `{ dual = true }`. No breaking change for games that need it.
- **Components ships empty:** Framework is genre-agnostic. Pre-defining Position/Velocity/Health was framework opinion — games define what they need in `src/core/components.lua`.
- **Canonical plugin exposes fragments on module:** Since `components.lua` is now empty, the canonical plugin example defines its own fragment IDs and exposes them on the module table so the spec can spawn entities with the correct fragments without reaching into private locals.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated all callers of the old Worlds.create() dual-world-by-default API**
- **Found during:** Task 2 (full `busted` run after empty components change)
- **Issue:** `plugin_harness.lua`, `context_spec.lua`, `canonical_plugin.lua`, and `canonical_plugin_spec.lua` all called `Worlds.create()` expecting dual-world behavior (server/client fields, spawn_server). After Task 1 changed the default, all these callers broke (17 errors in the full suite).
- **Fix:** Updated `plugin_harness.lua` to use `Worlds.create({ dual = true })`; updated `context_spec.lua` two tests to use dual-world; rewrote `canonical_plugin.lua` to define its own fragment IDs (removed dependency on now-empty components.lua) and expose them on the module table; updated `canonical_plugin_spec.lua` to use those exposed fragments.
- **Files modified:** `tests/helpers/plugin_harness.lua`, `tests/core/context_spec.lua`, `examples/canonical_plugin.lua`, `tests/canonical_plugin_spec.lua`
- **Verification:** `busted` suite: 162 successes / 0 failures / 0 errors
- **Committed in:** `e44d124`

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug, API callers broken by planned API change)
**Impact on plan:** Auto-fix was necessary and expected — changing the default of a widely-used function requires updating all existing callers. No scope creep.

## Issues Encountered

None — TDD cycle (RED → GREEN) worked as designed. The Rule 1 fix was the only unplanned work.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `src/core/worlds.lua` is ready for use by all plugins — single-world by default, dual opt-in
- `src/core/components.lua` is ready to receive game-specific fragment definitions
- Plugin harness uses dual-world, so all plugin tests can call `spawn_server` and `spawn_client`
- Full suite green (162 tests): ready to continue with remaining Phase 1 plans

---
*Phase: 01-core-infrastructure*
*Completed: 2026-03-01*
