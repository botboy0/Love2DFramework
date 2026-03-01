---
phase: 01-core-infrastructure
verified: 2026-03-02T00:30:00Z
status: passed
score: 19/19 must-haves verified
re_verification: false
---

# Phase 1: Core Infrastructure Verification Report

**Phase Goal:** A developer can register a plugin and have it receive a working `ctx` with a live event bus and ECS world
**Verified:** 2026-03-02
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A plugin registered in `plugin_list.lua` receives a `ctx` table containing `worlds`, `bus`, `config`, and `services` when `love.load` runs | VERIFIED | `main.lua` lines 29-34: `Context.new` assembles ctx with all four fields plus `transport`; `Registry:boot(ctx)` passes ctx to each `plugin:init(ctx)` |
| 2 | Emitting an event inside a `bus:on()` handler logs a warning and discards the emission — the flush does not recurse | VERIFIED | `bus.lua` lines 89-95: re-entrancy guard checks `self._flushing` and calls `self._log` with warning message then returns |
| 3 | Events emitted during `update()` are not delivered until `bus:flush()` is called — handlers see no events mid-update | VERIFIED | `bus.lua` lines 84-95: `emit()` appends to `_queue`; `flush()` at line 107 delivers from queue; `main.lua` line 59 calls `bus:flush()` once per tick |
| 4 | An entity spawned via `worlds` helpers exists in the correct world; raw `evolved.spawn()` is not reachable from plugin code | VERIFIED | `worlds.lua` wraps all `evolved.spawn()` calls; the only `evolved.spawn` in src/ is inside `worlds.lua` itself (lines 51, 60, 72); plugin code receives `ctx.worlds`, not `evolved` directly |
| 5 | Shutting down triggers plugin teardown on all registered plugins in reverse boot order | VERIFIED | `registry.lua` lines 244-252: `Registry:shutdown(ctx)` iterates `_boot_order` in reverse and calls `entry.module:shutdown(ctx)` for each plugin that defines it; `main.lua` line 70: `love.quit()` calls `_registry:shutdown(_ctx)` |

**Score:** 5/5 roadmap success criteria verified

---

### Must-Have Truths (from PLAN frontmatter — all 4 plans)

#### Plan 01-01: Worlds + Components

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `Worlds.create()` with no args returns a single-world handle with a `spawn()` method | VERIFIED | `worlds.lua` lines 27-87: `opts.dual` check; single-world branch returns table with `spawn()` |
| 2 | Single-world `spawn_server()` and `spawn_client()` error immediately with a descriptive message | VERIFIED | `worlds.lua` lines 76-83: both error with "single-world mode" in message |
| 3 | `Worlds.create({ dual = true })` preserves dual-world behavior with ServerTag/ClientTag | VERIFIED | `worlds.lua` lines 30-63: dual branch sets `server = { tag = server_tag }`, `client = { tag = client_tag }` |
| 4 | `components.lua` returns an empty table — no pre-defined fragments | VERIFIED | `src/core/components.lua` line 11: `return {}` |

#### Plan 01-02: Bus + Transport

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 5 | Bus in strict error_mode re-raises handler errors instead of catching them | VERIFIED | `bus.lua` lines 122-126: `if self._error_mode == "strict"` resets `_flushing` then calls `error(err, 0)` |
| 6 | Bus in tolerant error_mode (default) catches and logs handler errors | VERIFIED | `bus.lua` lines 127-129: else branch calls `self._log(...)` |
| 7 | `Transport.Null` provides no-op methods matching the full Transport API | VERIFIED | `transport.lua` lines 141-168: `NullTransport` class with all 7 methods; exposed as `Transport.Null` at line 168 |
| 8 | `Transport.Null:is_networkable()` always returns false | VERIFIED | `transport.lua` lines 150-152: returns `false` unconditionally |
| 9 | `Transport.Null:receive_all()` always returns empty table | VERIFIED | `transport.lua` lines 164-166: `return {}` |

#### Plan 01-03: Context + Registry

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 10 | `Context.new()` with no transport option sets `ctx.transport` to a NullTransport instance | VERIFIED | `context.lua` lines 82-88: `resolve_transport` returns `Transport.Null.new()` when transport is nil or false |
| 11 | `Context.new({ transport = true })` creates a real Transport and wires auto-bridge to bus | VERIFIED | `context.lua` lines 90-102: creates `Transport.new({outbound, inbound})` from `opts.transport_channels` |
| 12 | Auto-bridge: `bus:emit()` for a networkable event also queues it on transport | VERIFIED | `context.lua` lines 116-124: `install_auto_bridge` wraps `bus.emit` to call `transport:queue` when `is_networkable` is true |
| 13 | Auto-bridge: `bus:emit()` for a non-networkable event does NOT queue on transport | VERIFIED | `context.lua` line 120: `if transport:is_networkable(event)` guard; NullTransport always returns false |
| 14 | Registry resolves its own error_mode from config | VERIFIED | `registry.lua` lines 37-46 + 58: `resolve_error_mode(config, "registry", "strict")` |
| 15 | Registry in strict mode propagates plugin init errors | VERIFIED | `registry.lua` lines 230-235: strict branch calls `entry.module:init(ctx)` without pcall |
| 16 | Registry in tolerant mode logs plugin init errors and continues | VERIFIED | `registry.lua` lines 218-228: tolerant branch uses `pcall(entry.module.init, ...)` and logs on failure |

#### Plan 01-04: main.lua + canonical_plugin

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 17 | `love.quit()` calls `registry:shutdown(ctx)` when registry and ctx exist | VERIFIED | `main.lua` lines 68-72: `if _registry and _ctx then _registry:shutdown(_ctx) end` |
| 18 | `love.load()` threads config and transport options through to `Context.new()` | VERIFIED | `main.lua` lines 10-14: `_config` table; lines 23-34: config threaded to `Bus.new`, `Context.new`, `Registry.new` |
| 19 | Transport flush happens after bus flush in `love.update()` | VERIFIED | `main.lua` lines 54-61: `receive_all` → `bus:flush()` → `transport:flush()` in order |

**Score:** 19/19 must-have truths verified

---

### Required Artifacts

| Artifact | Status | Evidence |
|----------|--------|----------|
| `src/core/worlds.lua` | VERIFIED | Exists, 89 lines, exports `Worlds.create`, `Worlds.ServerTag`, `Worlds.ClientTag`; calls `evolved.spawn` |
| `src/core/components.lua` | VERIFIED | Exists, 11 lines, contains `return {}` |
| `src/core/bus.lua` | VERIFIED | Exists, 137 lines, exports `Bus.new`; `_error_mode` field and tolerant/strict dispatch |
| `src/core/transport.lua` | VERIFIED | Exists, 170 lines, exports `Transport.new` and `Transport.Null` at line 168 |
| `src/core/context.lua` | VERIFIED | Exists, 155 lines, exports `Context.new`; `transport` field on ctx at line 149 |
| `src/core/registry.lua` | VERIFIED | Exists, 254 lines, exports `Registry.new`; `error_mode`, `side` enforcement, `topological_sort`, `shutdown` |
| `src/core/plugin_list.lua` | VERIFIED | Exists, returns `{}` — explicit manifest, no auto-discovery |
| `main.lua` | VERIFIED | Exists, 72 lines; `love.load`, `love.update`, `love.quit` all implemented |
| `examples/canonical_plugin.lua` | VERIFIED | Exists, 92 lines; uses local `evolved.id(2)` fragments, supports single and dual world modes |
| `tests/core/worlds_spec.lua` | VERIFIED | Exists, 231 lines; 28 tests covering single-world, dual-world, and constant tests |
| `tests/core/components_spec.lua` | VERIFIED | Exists; asserts table type and emptiness |
| `tests/core/bus_spec.lua` | VERIFIED | Exists; covers error_mode strict/tolerant |
| `tests/core/transport_spec.lua` | VERIFIED | Exists; covers NullTransport and real Transport |
| `tests/core/context_spec.lua` | VERIFIED | Exists; covers transport wiring and auto-bridge |
| `tests/core/registry_spec.lua` | VERIFIED | Exists; covers error_mode and side enforcement |
| `tests/main_spec.lua` | VERIFIED | Exists, 351 lines; covers love.quit, update ordering, config threading |
| `tests/canonical_plugin_spec.lua` | VERIFIED | Exists; uses `CanonicalPlugin.Position/Velocity` fragments |

---

### Key Link Verification

| From | To | Via | Status | Evidence |
|------|-----|-----|--------|----------|
| `src/core/worlds.lua` | `lib/evolved.lua` | `evolved.spawn()` wrapped by `worlds:spawn()` | WIRED | `worlds.lua` line 16: `require("lib.evolved")`; lines 51, 60, 72: `evolved.spawn(...)` |
| `src/core/bus.lua` | `config.error_mode` | `error_mode` field set at construction | WIRED | `bus.lua` lines 36-46: `error_mode` resolved from opts; line 53: stored as `_error_mode` |
| `src/core/transport.lua` | `Transport.Null` | `NullTransport` exposed as `Transport.Null` | WIRED | `transport.lua` line 168: `Transport.Null = NullTransport` |
| `src/core/context.lua` | `src/core/transport.lua` | `Transport.Null.new()` in `resolve_transport()` | WIRED | `context.lua` line 24: `require("src.core.transport")`; line 87: `Transport.Null.new()` |
| `src/core/context.lua` | `src/core/bus.lua` | `install_auto_bridge` wraps `bus.emit` | WIRED | `context.lua` lines 116-124: `local original_emit = bus.emit` then override |
| `src/core/registry.lua` | `config.error_mode` | `resolve_error_mode` at construction | WIRED | `registry.lua` lines 37-46: `resolve_error_mode` function; line 58: called in `Registry.new` |
| `main.lua` | `src/core/registry.lua` | `love.quit()` calls `registry:shutdown(ctx)` | WIRED | `main.lua` line 3: `require("src.core.registry")`; line 70: `_registry:shutdown(_ctx)` |
| `main.lua` | `src/core/context.lua` | `Context.new` with transport option | WIRED | `main.lua` line 2: `require("src.core.context")`; line 29: `Context.new({...})` |
| `examples/canonical_plugin.lua` | `lib/evolved.lua` | Local `evolved.id()` for example-only fragments | WIRED | `canonical_plugin.lua` line 19: `require("lib.evolved")`; line 31: `evolved.id(2)` |

All 9 key links verified.

---

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CORE-01 | 01-03, 01-04 | Plugin registry boots plugins in topological dependency order via `plugin:init(ctx)` | SATISFIED | `registry.lua` lines 123-196: `topological_sort` (Kahn's BFS); `Registry:boot` calls `init` in sorted order |
| CORE-02 | 01-03, 01-04 | Plugin registry shuts down plugins in reverse order via `love.quit` | SATISFIED | `main.lua` line 68-72: `love.quit` calls `registry:shutdown`; `registry.lua` line 246: `for i = #self._boot_order, 1, -1` |
| CORE-03 | 01-02 | Deferred-dispatch event bus queues events during update and delivers on `bus:flush()` | SATISFIED | `bus.lua` lines 89-95: `emit()` appends to queue; lines 107-135: `flush()` delivers |
| CORE-04 | 01-02 | Event bus re-entrancy guard blocks emissions during flush with a logged warning | SATISFIED | `bus.lua` lines 90-94: `if self._flushing` check in `emit()` logs and returns |
| CORE-05 | 01-01 | ECS world management integrates evolved.lua with tag-based isolation (ServerTag/ClientTag) | SATISFIED | `worlds.lua` lines 22, 30-63: `ServerTag`/`ClientTag` constants; `spawn_server`/`spawn_client` add tags |
| CORE-06 | 01-01 | Single-world mode works without tags for simple games | SATISFIED | `worlds.lua` lines 64-87: single-world branch with no tag additions |
| CORE-07 | 01-03, 01-04 | Context object `ctx = { worlds, bus, config, services }` passed to all plugins | SATISFIED | `context.lua` lines 145-152: ctx returned with all four fields plus `transport` (superset) |
| CORE-08 | 01-01 | Shared components defined centrally in `src/core/components.lua` — no `evolved.id()` in plugin files | SATISFIED | `components.lua` ships as `return {}` — convention established; no plugin files have `evolved.id()` calls |
| CORE-09 | 01-02, 01-03 | Optional love.thread channel transport for client-server communication | SATISFIED | `transport.lua`: real `Transport.new` + `Transport.Null` stub; context wires transport always present |
| CORE-10 | 01-04 | Explicit plugin manifest (`plugin_list.lua`) — no auto-discovery | SATISFIED | `src/core/plugin_list.lua` returns `{}`; `main.lua` lines 38-42 iterates list — no globbing/auto-discovery |

All 10 CORE requirements satisfied. No orphaned requirements found (REQUIREMENTS.md traceability table marks all 10 as Complete at Phase 1).

---

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `main.lua` line 64-66 | `love.draw()` is a stub with comment "Future: call registered render systems" | Info | Expected — render systems are Phase 3+. Does not block any Phase 1 goal. |
| `examples/canonical_plugin.lua` lines 88-90 | `CanonicalPlugin:shutdown` is a no-op with comment | Info | Intentional — canonical example; comment explains future use case. |

No blocker anti-patterns found. The two noted items are intentional and documented.

---

### Test Suite Results

202 successes / 0 failures / 0 errors — full `busted` run as of verification timestamp.

The `[Bus] Handler error for event 'test': ...` line visible in test output is expected — it is logged by a tolerant-mode test verifying that handler errors are caught and logged, not propagated.

---

### Human Verification Required

The following items cannot be verified programmatically and require a running Love2D instance:

#### 1. love.load full boot with plugin

**Test:** Create a simple plugin in `src/plugins/hello/init.lua` that logs "hello from ctx" in `init(ctx)`, add it to `plugin_list.lua`, and run `love .`
**Expected:** Console shows "hello from ctx" during startup; no errors thrown
**Why human:** Love2D `love.load` requires the Love2D runtime to execute; busted does not run Love2D's main loop

#### 2. Transport flush ordering at runtime

**Test:** Enable a real Transport instance in `_config`, mark an event networkable, emit it, and verify it arrives on the inbound channel next tick
**Why human:** End-to-end love.thread channel behavior requires the Love2D threading runtime

---

### Notes on Naming Discrepancy

The ROADMAP success criterion 5 states "triggers `plugin:quit()` on all registered plugins". The actual implementation uses `plugin:shutdown(ctx)`. This is a documentation inconsistency in ROADMAP.md — the implementation is correct and the behavior is fully tested (202 passing tests include explicit `registry:shutdown` tests). The ROADMAP should be updated to say `plugin:shutdown(ctx)` in a future documentation pass.

---

## Summary

Phase 1 goal is fully achieved. All 19 must-have truths are verified against actual code, all 10 CORE requirements are satisfied, all 9 key links are wired, and the full test suite passes with 202 tests and 0 failures. The core infrastructure contract — ECS world, event bus, plugin registry, transport stub, and context assembly — is implemented, tested, and integrated in the game loop.

---

_Verified: 2026-03-02_
_Verifier: Claude (gsd-verifier)_
