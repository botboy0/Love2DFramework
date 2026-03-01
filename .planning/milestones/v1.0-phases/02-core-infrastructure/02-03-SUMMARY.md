---
phase: 02-core-infrastructure
plan: 03
subsystem: infra
tags: [plugin-registry, topological-sort, transport, binser, channels, lua, tdd, busted]

# Dependency graph
requires:
  - phase: 02-core-infrastructure/02-01
    provides: "lib/binser.lua serialization library and deferred-dispatch event bus"
  - phase: 02-core-infrastructure/02-02
    provides: "Context.new(opts) factory for plugin:init(ctx) API"

provides:
  - "src/core/registry.lua — Plugin registry with topological sort (Kahn's BFS) and fail-fast boot"
  - "src/core/plugin_list.lua — Explicit boot manifest (empty until game plugins added)"
  - "src/core/transport.lua — love.thread channel transport with binser serialization and networkable whitelist"

affects:
  - 02-core-infrastructure/02-04
  - all plugin plans
  - main.lua integration

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Topological sort for plugin boot ordering: Kahn's BFS algorithm detects cycles and produces deterministic dependency order"
    - "Fail-fast validation: all dependency checks complete before any plugin:init runs"
    - "Injectable channel abstraction: Transport accepts duck-typed channels (love.thread or mock) for test isolation"
    - "Networkable whitelist: explicit opt-in per event name — nothing crosses transport boundary by default"
    - "binser round-trip: serialize(table) -> push -> pop -> deserialize()[1] — vals array indexing required"

key-files:
  created:
    - src/core/registry.lua
    - src/core/plugin_list.lua
    - src/core/transport.lua
    - tests/core/registry_spec.lua
    - tests/core/transport_spec.lua
  modified: []

key-decisions:
  - "Kahn's BFS for topological sort: naturally detects cycles when not all nodes are processed; stable within same degree (preserves registration order)"
  - "Fail-fast in two phases: validate_deps() checks all deps exist first, then topological_sort() detects cycles — both error before any plugin:init runs"
  - "binser.deserialize returns (vals_array, n): receive() must index vals[1] to get the original message table"
  - "Injectable log function for Transport: Transport.new({ log = fn }) allows test warning capture without print override"
  - "Warning-not-drop policy: queue depth warnings log via injected log function, messages are never dropped"

patterns-established:
  - "Plugin boot manifest: src/core/plugin_list.lua is the single authoritative list — no auto-discovery"
  - "Transport loopback test: same channel as both outbound and inbound verifies round-trip without love.thread"
  - "In-place table clear: `while #t > 0 do table.remove(t) end` preserves Lua closure references vs reassigning t = {}"

requirements-completed:
  - INFRA-02
  - INFRA-04

# Metrics
duration: 5min
completed: 2026-03-01
---

# Phase 2 Plan 03: Plugin Registry and Transport Layer Summary

**Topological-sort plugin registry with fail-fast boot, and injectable binser/channel transport layer with networkable event whitelist**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-01T18:12:43Z
- **Completed:** 2026-03-01T18:17:16Z
- **Tasks:** 2
- **Files modified:** 5 (3 source, 2 test)

## Accomplishments

- Plugin registry boots plugins in topological dependency order (Kahn's BFS), errors with descriptive messages before any init runs on missing or cyclic deps
- Transport layer serializes Lua tables via binser through a duck-typed channel interface — works with love.thread.Channel in production and mock channels in tests
- Only events explicitly marked via `mark_networkable()` cross the transport boundary; non-networkable events are silently ignored
- Queue depth warning fires with injectable log function when threshold is exceeded — messages are never dropped
- 37 tests pass across both suites (16 registry, 21 transport); selene and stylua clean

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Failing registry tests** - `f2fb239` (test)
2. **Task 1 GREEN: Plugin registry + plugin_list** - `f51a595` (feat)
3. **Task 2 RED: Failing transport tests** - `77512cb` (test)
4. **Task 2 GREEN: Transport layer** - `136ba4d` (feat)

_Note: TDD tasks have two commits each (test RED, feat GREEN). No refactor pass needed._

## Files Created/Modified

- `src/core/registry.lua` — Registry.new(), register(), boot() with Kahn's topological sort, shutdown() in reverse order (183 lines)
- `src/core/plugin_list.lua` — Empty boot manifest; game plugins added in future phases (16 lines)
- `src/core/transport.lua` — Transport.new() with injectable channels, mark_networkable, queue, flush, send, receive, receive_all (135 lines)
- `tests/core/registry_spec.lua` — 16 tests: creation, boot order, diamond deps, missing dep error, cycle detection, shutdown (251 lines)
- `tests/core/transport_spec.lua` — 21 tests: new, whitelist, queue, send, receive, flush, round-trip, receive_all, warning threshold (268 lines)

## Decisions Made

- **Kahn's BFS for topological sort:** Straightforward algorithm that naturally detects cycles when fewer nodes are processed than registered. Preserves registration order for nodes at the same dependency depth — stable, deterministic output.
- **binser.deserialize returns (vals_array, n):** `binser.deserialize(raw)` returns a table of all deserialized values plus a count. `receive()` indexes `vals[1]` to extract the message table. Discovered via debugging after initial implementation returned the outer array.
- **In-place table clear for test closures:** The shutdown test needed to clear `log` between boot and shutdown phases. `log = {}` reassignment creates a new table but plugin closures hold the original reference. Fixed with `while #log > 0 do table.remove(log) end` to clear in-place.
- **Warning threshold fires on queue after insertion:** Warning check runs inside `queue()` after inserting the event — cleaner than checking before, and accurately reflects actual queue depth at warning time.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed test closure reference issue in shutdown test**
- **Found during:** Task 1 GREEN run
- **Issue:** Shutdown test did `log = {}` to clear init entries between boot and shutdown phases. Plugin closures captured the original `log` table, so reassignment broke the reference — shutdown calls wrote to the old table, test read from the new empty one.
- **Fix:** Changed to in-place clear: `while #log > 0 do table.remove(log) end` — preserves the closure reference.
- **Files modified:** `tests/core/registry_spec.lua`
- **Verification:** All 16 registry tests pass, including shutdown order test.
- **Committed in:** f51a595 (Task 1 GREEN — fixed before commit)

**2. [Rule 1 - Bug] Fixed binser.deserialize indexing in receive()**
- **Found during:** Task 2 GREEN run (tests failing on receive)
- **Issue:** Initial implementation called `binser.deserialize(raw)` and returned the result directly. binser returns `(vals_array, n)` where `vals_array` is a numerically-indexed table of deserialized values, not the value itself. So `msg.event` was nil.
- **Fix:** Changed to `local vals = binser.deserialize(raw); return vals[1]` to extract the first deserialized value.
- **Files modified:** `src/core/transport.lua`
- **Verification:** All 21 transport tests pass including round-trip and receive_all tests.
- **Committed in:** 136ba4d (Task 2 GREEN commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — implementation bugs)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered

- binser API behavior (returning vals_array, not the value directly) is not immediately obvious from the README. Documented in patterns-established for future reference.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plugin registry is the boot orchestrator — main.lua wires it up in plan 02-04
- plugin_list.lua is ready to receive game plugin entries in Phase 3+
- Transport layer is ready for use; production channels (`love.thread.getChannel("server_to_client")`) wired in 02-04
- No blockers for 02-04 (game loop integration) or subsequent plans

---
*Phase: 02-core-infrastructure*
*Completed: 2026-03-01*

## Self-Check: PASSED

All files confirmed present on disk. All commits confirmed in git history.
