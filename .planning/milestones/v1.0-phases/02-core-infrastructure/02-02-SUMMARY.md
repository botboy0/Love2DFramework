---
phase: 02-core-infrastructure
plan: 02
subsystem: infra
tags: [evolved.lua, ecs, components, context, services, lua]

requires:
  - phase: 02-core-infrastructure/02-01
    provides: "lib/evolved.lua vendored ECS library and deferred-dispatch event bus"

provides:
  - "src/core/components.lua — Position, Velocity, Health fragment IDs (single source of truth)"
  - "src/core/worlds.lua — Worlds.create() dual world factory with tag-based server/client isolation"
  - "src/core/context.lua — Context.new(opts) bundling worlds, bus, config, services for plugin:init(ctx)"
  - "Services registry with register/get and fail-fast error on missing service"

affects:
  - 02-core-infrastructure/02-03
  - 02-core-infrastructure/02-04
  - all plugin plans

tech-stack:
  added: []
  patterns:
    - "Tag-based dual-world isolation: ServerTag/ClientTag fragments on evolved.lua singleton"
    - "Context injection pattern: every plugin receives ctx = { worlds, bus, config, services }"
    - "Fail-fast services registry: get() errors with descriptive message on missing service"
    - "ECS singleton cleanup in tests: track spawned entities, destroy in after_each"

key-files:
  created:
    - src/core/components.lua
    - src/core/worlds.lua
    - src/core/context.lua
    - tests/core/components_spec.lua
    - tests/core/worlds_spec.lua
    - tests/core/context_spec.lua
  modified: []

key-decisions:
  - "Tag-based world isolation: evolved.lua is a global singleton, no multi-world support; ServerTag/ClientTag fragments on entities provide clean query-level separation without forking the library"
  - "Context.new() returns plain table with metatable, not a closure — consistent with Lua module idiom and testable without mocking"
  - "Services.register() errors on duplicate registration — prevents silent overwrites at boot time"

patterns-established:
  - "ctx = Context.new({ worlds = worlds, bus = bus, config = {} }) — standard plugin context construction"
  - "worlds:spawn_server(components) / worlds:spawn_client(components) — world-scoped entity creation"
  - "evolved.builder():include(ServerTag, MyFragment):build() — world-scoped query pattern"

requirements-completed:
  - INFRA-03
  - INFRA-05

duration: 4min
completed: 2026-03-01
---

# Phase 02 Plan 02: Dual ECS Worlds and Context Object Summary

**Tag-based dual ECS world isolation via evolved.lua ServerTag/ClientTag fragments, shared component definitions, and plugin context object with fail-fast services registry**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-01T18:05:30Z
- **Completed:** 2026-03-01T18:09:30Z
- **Tasks:** 2
- **Files modified:** 6 (3 source, 3 test)

## Accomplishments

- Shared component fragments (Position, Velocity, Health) defined once via `evolved.id(3)` — usable in both worlds
- Dual-world isolation via tag-based namespacing: `ServerTag`/`ClientTag` fragments on evolved.lua singleton; server queries include `ServerTag`, client queries include `ClientTag`
- Context object (`ctx`) bundles worlds, bus, config, and services — matches the `plugin:init(ctx)` API contract from CLAUDE.md
- Services registry with fail-fast `get()` (descriptive error message) and duplicate-registration guard in `register()`
- 37 tests total across 3 suites; all pass with selene and stylua clean

## Task Commits

Each task was committed atomically:

1. **Task 1: Shared component definitions and dual ECS worlds** - `e654f94` (feat)
2. **Task 2: Context object pattern** - `f0b5e7c` (feat)

_Note: TDD tasks: RED was implicit (modules did not exist), GREEN is the task commit_

## Files Created/Modified

- `src/core/components.lua` — Position, Velocity, Health fragment IDs via `evolved.id(3)`, single source of truth
- `src/core/worlds.lua` — `Worlds.create()` returns dual-world handle; `spawn_server()`/`spawn_client()` add tags automatically; `Worlds.ServerTag`/`Worlds.ClientTag` are module-level constants
- `src/core/context.lua` — `Context.new(opts)` factory with embedded `Services` sub-object; `register(name, svc)` and `get(name)` with fail-fast error
- `tests/core/components_spec.lua` — 6 tests: fragment uniqueness, type, positive values
- `tests/core/worlds_spec.lua` — 17 tests: create() shape, tag distinctness, isolation (server entity absent from client query and vice versa), query independence
- `tests/core/context_spec.lua` — 14 tests: fields, defaults, service register/get, duplicate error, missing-service error message format

## Decisions Made

- **Tag-based world isolation:** evolved.lua is a global singleton without multi-world support. ServerTag/ClientTag fragments on entities provide clean query-level separation without library modifications or forks. All server systems include `ServerTag` in their query; all client systems include `ClientTag`.
- **Module-level tag constants:** `Worlds.ServerTag` and `Worlds.ClientTag` are created at module load time (not per `create()` call) so all call sites share the same fragment IDs — essential for cross-call query compatibility.
- **Singleton ECS test cleanup:** Tests track spawned entities in a `spawned` table and call `evolved.destroy()` in `after_each` — prevents test-to-test state leak through the global singleton.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Downloaded evolved.lua before proceeding**
- **Found during:** Task 1 pre-check
- **Issue:** `lib/evolved.lua` was missing at execution start (plan 02-01 runs in parallel per wave 1; it had actually already completed, but the file appeared missing at check time due to git status snapshot)
- **Fix:** `curl -sL` download of evolved.lua into `lib/`; file was already committed by 02-01 (`e330f86`), so the download was a no-op in git terms
- **Files modified:** lib/evolved.lua (re-downloaded, already tracked)
- **Verification:** `lua -e "dofile('lib/evolved.lua')"` prints `evolved OK`
- **Committed in:** e654f94 (Task 1 — file was not re-committed since it matched HEAD)

**2. [Rule 1 - Bug] Fixed test isolation in worlds_spec**
- **Found during:** Task 1 GREEN run
- **Issue:** Test `"client entity is not found in server query"` failed (count 1 instead of 0) because evolved.lua is a global singleton — entities spawned in an earlier test (`"server entity is found in server query"`) persisted
- **Fix:** Added `spawned` tracking table + `after_each` cleanup using `evolved.defer()` / `evolved.destroy()` / `evolved.commit()` to clean up singleton state between tests
- **Files modified:** tests/core/worlds_spec.lua
- **Verification:** All 23 worlds tests pass in isolation and when run together with components tests
- **Committed in:** e654f94 (Task 1 — fixed before commit)

---

**Total deviations:** 2 auto-fixed (1 blocking pre-condition, 1 test isolation bug)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered

- `validate_architecture_spec.lua` has 2 pre-existing failures (tests assume no src/ Lua files exist, but files were added by plan 02-01 and this plan). These failures pre-date this plan and are out of scope. Target test suites (components, worlds, context) all pass.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Component fragments, dual-world factory, and context object are complete
- Plan 02-03 (plugin registry) and 02-04 (game loop integration) can proceed
- The `ctx = Context.new(...)` pattern is the standard interface all plugin plans will depend on

---
*Phase: 02-core-infrastructure*
*Completed: 2026-03-01*
