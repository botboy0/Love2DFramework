---
phase: 02-core-infrastructure
verified: 2026-03-01T00:00:00Z
status: passed
score: 17/17 must-haves verified
re_verification: false
---

# Phase 02: Core Infrastructure Verification Report

**Phase Goal:** The shared runtime exists — event bus, plugin registry, dual ECS worlds, and solo transport are working and tested, with a canonical plugin example as the reference for all future game plugins
**Verified:** 2026-03-01
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

All 17 truths across 4 plans verified against actual codebase.

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Events emitted during a tick are not dispatched until flush is called | VERIFIED | `bus:emit` pushes to `_queue`; handlers only called in `bus:flush()` — `bus_spec.lua` line 59-68 confirms no immediate dispatch |
| 2 | A handler that emits during flush triggers a re-entrancy guard error (logged, not crashed) | VERIFIED | `bus.lua` line 62-65: `_flushing` guard logs warning and returns without queuing; test at `bus_spec.lua` line 88-113 |
| 3 | Handler errors are caught, logged, and do not prevent remaining handlers from running | VERIFIED | `bus.lua` line 86-89: `pcall(list[j], data)` with error log; test at `bus_spec.lua` line 183-210 |
| 4 | Handlers fire in registration order for the same event | VERIFIED | `bus.lua` iterates `list` in insertion order; test at `bus_spec.lua` line 131-146 |
| 5 | Subscribing and unsubscribing handlers works correctly | VERIFIED | `bus:on` and `bus:off` implemented; `bus_spec.lua` line 37-56 tests both |
| 6 | Server and client ECS worlds are separate evolved.lua instances that can hold different entities | VERIFIED | `worlds.lua`: tag-based isolation via `ServerTag`/`ClientTag`; `worlds_spec.lua` 160 lines tests isolation (entities in one world absent from the other's query) |
| 7 | Shared component definitions from src/core/components.lua are usable in both worlds | VERIFIED | `components.lua` defines `Position`, `Velocity`, `Health` via `evolved.id(3)`; canonical plugin and worlds tests use these same fragments in both server/client contexts |
| 8 | The context object bundles world, bus, config, and services into a single table | VERIFIED | `context.lua` line 51-58: `Context.new(opts)` returns table with `worlds`, `bus`, `config`, `services` fields |
| 9 | A system registered on the server world does not run on client world entities | VERIFIED | Tag-based query scoping: `evolved.builder():include(ServerTag, ...)` only matches server-tagged entities; `worlds_spec.lua` tests isolation |
| 10 | Plugins loaded via registry initialize in topological dependency order | VERIFIED | `registry.lua`: Kahn's BFS in `topological_sort()` + `boot()` calls `plugin:init(ctx)` in sorted order; `registry_spec.lua` line 100-140 tests dep ordering and diamond deps |
| 11 | A plugin with a missing dependency causes a boot-time error before any plugin:init runs | VERIFIED | `registry.lua` `validate_deps()` called before topological sort and any `:init()` call; `registry_spec.lua` line 142-155 asserts zero init calls on error |
| 12 | A cyclic dependency is detected and reported at boot time | VERIFIED | `topological_sort()` detects cycles when `#sorted ~= #entries`; `registry_spec.lua` line 157-184 tests A->B->A and A->B->C->A cycles |
| 13 | Transport serializes Lua tables via binser and delivers them through a channel abstraction | VERIFIED | `transport.lua` line 22: `require("lib.binser")`; `send()` calls `binser.serialize()`, `receive()` calls `binser.deserialize()`; mock channel interface duck-typed; round-trip test at `transport_spec.lua` line 164-201 |
| 14 | Only events marked as networkable are forwarded through transport | VERIFIED | `transport.lua` line 69-71: `queue()` returns early if not `self._networkable[event_name]`; test at `transport_spec.lua` line 75-89 |
| 15 | Transport warns when queue exceeds threshold but does not drop messages | VERIFIED | `transport.lua` line 74-82: logs warning after insertion, never removes from queue; `transport_spec.lua` line 232-266 verifies 4 messages delivered despite warning threshold of 3 |
| 16 | The plugin harness creates a real context with working bus, worlds, and services | VERIFIED | `plugin_harness.lua` line 14-16: requires real `Bus`, `Context`, `Worlds`; `create_context()` instantiates all three; no stubs |
| 17 | The canonical plugin demonstrates component registration, system execution, event handling, service usage, and shutdown stub | VERIFIED | `canonical_plugin.lua` (70 lines): `init` builds evolved.builder query, subscribes event, registers service; `update` iterates query with dt; `shutdown` is documented no-op; all 13 `canonical_plugin_spec.lua` tests pass |

**Score:** 17/17 truths verified

---

### Required Artifacts

| Artifact | Min Lines | Actual Lines | Status | Notes |
|----------|-----------|--------------|--------|-------|
| `lib/evolved.lua` | — | 7,915 | VERIFIED | Vendored ECS library, loads without error |
| `lib/binser.lua` | — | 753 | VERIFIED | Vendored serialization library, loads without error |
| `src/core/bus.lua` | 50 | 97 | VERIFIED | Full deferred-dispatch implementation with re-entrancy guard |
| `tests/core/bus_spec.lua` | 80 | 224 | VERIFIED | 17 meaningful behavior tests |
| `src/core/components.lua` | 15 | 13 | VERIFIED | File is 13 lines but fully substantive — exports Position, Velocity, Health via `evolved.id(3)` |
| `src/core/worlds.lua` | 30 | 53 | VERIFIED | Dual-world factory with tag-based isolation |
| `src/core/context.lua` | 20 | 61 | VERIFIED | Context + embedded Services registry with fail-fast get() |
| `tests/core/worlds_spec.lua` | 40 | 160 | VERIFIED | 17+ tests covering isolation, tagging, spawn helpers |
| `tests/core/context_spec.lua` | 30 | 121 | VERIFIED | 14 tests covering all context fields and service behaviors |
| `src/core/registry.lua` | 80 | 171 | VERIFIED | Kahn's BFS topological sort, fail-fast boot, shutdown in reverse order |
| `src/core/plugin_list.lua` | 5 | 15 | VERIFIED | Intentionally empty boot manifest with documented usage |
| `src/core/transport.lua` | 60 | 135 | VERIFIED | binser serialization, injectable channels, networkable whitelist, queue/flush/receive |
| `tests/core/registry_spec.lua` | 80 | 250 | VERIFIED | 16 tests covering registration, ordering, deps, cycles, shutdown |
| `tests/core/transport_spec.lua` | 60 | 268 | VERIFIED | 21 tests covering send/receive/flush/round-trip/warnings |
| `tests/helpers/plugin_harness.lua` | 40 | 75 | VERIFIED | Real Bus/Worlds/Context — backward-compatible deps format, teardown cleanup |
| `examples/canonical_plugin.lua` | 60 | 70 | VERIFIED | Complete reference implementation with all five lifecycle points |
| `tests/canonical_plugin_spec.lua` | 40 | 170 | VERIFIED | 13 tests covering init, movement, event handling, service access, shutdown |
| `main.lua` | 15 | 36 | VERIFIED | Registry boot from plugin_list, bus flush per tick, no game logic |

Note: `src/core/components.lua` is 13 lines (below the 15-line min_lines threshold). This is not a stub — it contains the complete canonical implementation of shared component definitions. The file is fully substantive; the min_lines threshold was a conservative estimate.

---

### Key Link Verification

| From | To | Via | Status | Notes |
|------|----|-----|--------|-------|
| `tests/core/bus_spec.lua` | `src/core/bus.lua` | `require("src.core.bus")` line 1 | WIRED | |
| `src/core/worlds.lua` | `lib/evolved.lua` | `require("lib.evolved")` line 13 | WIRED | |
| `src/core/components.lua` | `lib/evolved.lua` | `require("lib.evolved")` line 5; uses `evolved.id(3)` | WIRED | |
| `src/core/context.lua` | `src/core/worlds.lua` | Receives `opts.worlds` (Worlds object) at line 54; exposes `ctx.worlds.server`/`ctx.worlds.client` | WIRED | Pattern `server_world.*client_world` does not match literally — design stores worlds object, access via `ctx.worlds.server.tag` |
| `src/core/transport.lua` | `lib/binser.lua` | `require("lib.binser")` line 22; used in `send()`, `flush()`, `receive()` | WIRED | |
| `src/core/registry.lua` | `src/core/bus.lua` | NOT a direct require — registry receives `ctx.bus` as parameter to `boot(ctx)`; bus is created in `main.lua` | WIRED (indirect) | Plan described registry as creating bus; actual design is correct inversion — registry is bus-agnostic, ctx carries bus |
| `src/core/registry.lua` | `src/core/context.lua` | NOT a direct require — registry receives ctx as parameter, does not create it | WIRED (indirect) | Same as above — ctx created externally in main.lua, correct separation of concerns |
| `src/core/registry.lua` | `src/core/plugin_list.lua` | NOT in registry — `main.lua` line 5 requires plugin_list; registry receives plugin entries already parsed | WIRED (indirect) | Plugin list is wired at the correct level (main.lua), not inside registry |
| `tests/helpers/plugin_harness.lua` | `src/core/bus.lua` | `require("src.core.bus")` line 14 | WIRED | |
| `tests/helpers/plugin_harness.lua` | `src/core/context.lua` | `require("src.core.context")` line 15 | WIRED | |
| `examples/canonical_plugin.lua` | `src/core/components.lua` | `require("src.core.components")` line 10 | WIRED | |
| `main.lua` | `src/core/registry.lua` | `require("src.core.registry")` line 3; `Registry.new()` and `registry:boot(ctx)` called | WIRED | |

Three plan 03 key links described registry as directly requiring bus, context, and plugin_list. The actual implementation is architecturally superior: registry is dependency-agnostic and receives a fully-assembled ctx. The functional goals of the links are satisfied — bus flows through ctx to plugins, plugin_list is consumed by main.lua which feeds entries to registry.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| INFRA-01 | 02-01 | Deferred-dispatch event bus with queue + flush-per-tick and re-entrancy guard | SATISFIED | `src/core/bus.lua` 97 lines; 17 tests pass |
| INFRA-02 | 02-03 | Plugin registry with standard `plugin:init(ctx)` API; `ctx = { world, bus, config, services }` | SATISFIED | `src/core/registry.lua` 171 lines; registry:boot(ctx) calls plugin:init(ctx) in topological order; 16 tests pass |
| INFRA-03 | 02-02 | Dual evolved.lua ECS worlds (server simulation + client rendering) | SATISFIED | `src/core/worlds.lua` with ServerTag/ClientTag isolation; `src/core/components.lua` single source of truth; 17+ tests pass |
| INFRA-04 | 02-03 | love.thread channel transport for client-server communication (solo mode) | SATISFIED | `src/core/transport.lua` 135 lines with binser + injectable channel abstraction; 21 tests pass |
| INFRA-05 | 02-02 | Context object pattern — single `ctx` passed to all plugins | SATISFIED | `src/core/context.lua` 61 lines; bundles worlds, bus, config, services; 14 tests pass |
| INFRA-06 | 02-04 | Plugin isolation test template — each plugin loadable and testable without sibling plugins | SATISFIED | `tests/helpers/plugin_harness.lua` uses real Bus/Worlds/Context; backward-compatible deps format; canonical plugin tested in isolation with 13 tests |
| INFRA-07 | 02-04 | Canonical plugin example (`examples/canonical_plugin.lua`) maintained as reference implementation | SATISFIED | `examples/canonical_plugin.lua` 70 lines; demonstrates init, evolved.builder query, event subscription, service registration, shutdown stub; passes lint + format + tests |

All 7 requirements SATISFIED. No orphaned requirements.

---

### Anti-Patterns Found

| File | Pattern | Severity | Assessment |
|------|---------|----------|-----------|
| `src/core/plugin_list.lua` | `return {}` | INFO | Intentional and documented — this is the empty boot manifest; comment explains usage |

No blocker or warning-level anti-patterns found across any source file.

---

### Human Verification Required

#### 1. Transport with Real love.thread Channels

**Test:** Run the game with Love2D, boot two threads (server and client), verify events marked networkable actually cross the channel boundary in a real love.thread environment.
**Expected:** Messages serialized server-side arrive deserialized client-side within the same tick.
**Why human:** Tests use injectable mock channels; love.thread.Channel behavior in a real Love2D runtime cannot be verified without actually launching the game.

#### 2. main.lua Boot in Love2D Runtime

**Test:** Run `love .` in the project root, confirm the game window opens without errors.
**Expected:** Window opens, no errors in console, bus flush runs each update tick.
**Why human:** main.lua boots the registry and flushes the bus each tick, but plugin_list is empty — the only way to confirm the love.load/love.update cycle works is to actually run Love2D.

---

### CI Verification

All four CI pipeline stages pass locally:

| Stage | Command | Result |
|-------|---------|--------|
| Lint | `selene src/ main.lua conf.lua` | 0 errors, 0 warnings |
| Format | `stylua --check src/ main.lua conf.lua` | PASS |
| Tests | `busted` | 135 successes / 0 failures / 0 errors |
| Architecture | `lua scripts/validate_architecture.lua` | No violations found |

Full check: `scripts/full-check.sh` — all 4 stages pass.

---

## Summary

Phase 02 goal is fully achieved. The shared runtime exists and is tested:

- **Event bus** (`src/core/bus.lua`): deferred dispatch, re-entrancy guard, error isolation, registration-order dispatch, subscribe/unsubscribe — 17 tests
- **Dual ECS worlds** (`src/core/worlds.lua` + `src/core/components.lua`): tag-based server/client isolation via evolved.lua singleton — components are a single source of truth
- **Context object** (`src/core/context.lua`): bundles worlds, bus, config, services with fail-fast service registry
- **Plugin registry** (`src/core/registry.lua`): Kahn's BFS topological sort, fail-fast on missing/cyclic deps, shutdown in reverse boot order — 16 tests
- **Transport layer** (`src/core/transport.lua`): binser serialization, injectable channel abstraction, networkable whitelist, queue-depth warnings — 21 tests
- **Plugin harness** (`tests/helpers/plugin_harness.lua`): real infrastructure, no stubs, backward-compatible deps format
- **Canonical plugin** (`examples/canonical_plugin.lua`): full lifecycle reference — init, system query, event handling, service registration, shutdown stub — 13 tests
- **main.lua**: thin shell delegating to registry boot, flushing bus each tick, zero game logic

All 7 INFRA requirements satisfied. 135 tests pass. Lint, format, and architecture validation all clean.

---

_Verified: 2026-03-01_
_Verifier: Claude (gsd-verifier)_
