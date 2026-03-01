# Phase 1: Core Infrastructure - Research

**Researched:** 2026-03-01
**Domain:** Love2D + evolved.lua ECS framework wiring (Lua)
**Confidence:** HIGH — all key findings verified against actual source files in the repo

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Single-world mode**
- Activated via flag on `Worlds.create()` — e.g. `Worlds.create({ single = true })`
- Single-world is the **default** — calling `Worlds.create()` with no args gives single-world mode
- Dual-world (server/client tags) is opt-in
- In single-world mode, `spawn_server()` and `spawn_client()` **error** if called — forces developers to use `spawn()`
- Plugin side declarations (`side = "server"` / `side = "client"`) are **optional** on the plugin manifest
  - If declared, the registry enforces it (server plugin can't depend on client plugin, etc.)
  - If omitted, plugin gets full `ctx` with access to both worlds
  - Single-world mode ignores side declarations

**Transport-bus wiring**
- **Auto-bridge**: when transport is enabled, the bus automatically forwards any event marked as networkable to transport — plugins just call `bus:emit()` as normal
- **Layered opt-in**: one field, two modes
  - `transport = true` → framework creates Transport with sensible default channels, wires to bus
  - `transport = Transport.new({...})` → framework uses the provided instance, just wires to bus
  - `transport = nil/false` → no transport
- Plugins mark their own events as networkable during init via `ctx.transport:mark_networkable("event_name")`
- **Null object pattern**: if transport is disabled, `ctx.transport` is a stub with no-op methods — plugins never need to guard with `if ctx.transport then`. Architecture validator (Phase 2) will catch "marking events networkable but transport isn't enabled."

**Component ownership**
- All components defined centrally in `src/core/components.lua` — no `evolved.id()` calls in plugin files
- The file ships **empty** — each game defines its own components; framework doesn't prescribe which ones
- **Flat table** structure — just `Components.X, Components.Y = evolved.id(2)`, no grouping or sub-tables
- No runtime guard against `evolved.id()` outside components.lua — CLAUDE.md rule + architecture validator (Phase 2) is sufficient enforcement

**Error philosophy**
- **Config-driven error modes** with global default and per-module overrides
- **Two levels only**: `strict` (crash on error) and `tolerant` (log and continue)
- No `silent` mode
- **Sensible defaults** (used when no config provided):
  - `registry` → strict
  - `services` → strict
  - `bus` → tolerant
  - `transport` → tolerant

### Claude's Discretion
- Exact implementation of the null transport stub
- How `Worlds.create()` flag is named internally (single/dual/mode)
- Default channel names for `transport = true` mode
- How config error_modes merge (global first, module override wins)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CORE-01 | Plugin registry boots plugins in topological dependency order via `plugin:init(ctx)` API | Registry fully implemented — Kahn's BFS topo sort. Needs: error_mode integration, optional side enforcement |
| CORE-02 | Plugin registry shuts down plugins in reverse order via `love.quit` | Shutdown method fully implemented. Needs: `love.quit` wiring in main.lua |
| CORE-03 | Deferred-dispatch event bus queues events during update and delivers on `bus:flush()` | Bus fully implemented with queue+flush. Needs: error_mode integration, transport auto-bridge |
| CORE-04 | Event bus re-entrancy guard blocks emissions during flush with a logged warning | Re-entrancy guard fully implemented and tested. No changes needed for core behavior |
| CORE-05 | ECS world management integrates evolved.lua with tag-based isolation (ServerTag/ClientTag) | Dual-world exists. Needs: single-world mode flag, `spawn()` helper for single mode, error on wrong spawn in wrong mode |
| CORE-06 | Single-world mode works without tags for simple games | Not yet implemented. Needs: `Worlds.create({ single = true })` (or no args), `worlds:spawn()` method, error guards |
| CORE-07 | Context object `ctx = { worlds, bus, config, services }` passed to all plugins | Context implemented. Needs: `transport` field added, config error_modes support |
| CORE-08 | Shared components defined centrally in `src/core/components.lua` — no `evolved.id()` in plugin files | File exists but ships with 3 example fragments. Needs: cleared to empty (ships empty, games define their own) |
| CORE-09 | Optional love.thread channel transport for client-server communication | Transport implemented. Needs: null stub, auto-bridge to bus, `transport = true` shorthand in Context.new |
| CORE-10 | Explicit plugin manifest (`plugin_list.lua`) — no auto-discovery | Already implemented and correct. No changes needed |
</phase_requirements>

---

## Summary

Phase 1 is a **refinement phase, not a greenfield phase**. All seven core modules already exist in `src/core/`: `bus.lua`, `worlds.lua`, `registry.lua`, `context.lua`, `transport.lua`, `components.lua`, and `plugin_list.lua`. The test suite is also complete with 135 passing tests across all modules. `main.lua` wires them at startup.

The phase task is to bring each module into conformance with the locked decisions from CONTEXT.md. The gaps are well-defined: single-world mode on `Worlds`, transport null stub + auto-bridge on `Transport`/`Context`, error_mode config plumbing on `Bus`/`Registry`/`Services`, the `love.quit` hook in `main.lua`, and clearing `components.lua` to empty. Each module change requires updating its corresponding `_spec.lua` with tests covering the new behavior.

**Primary recommendation:** Work module by module in dependency order (components → worlds → bus → transport → context → registry → main), updating both source and spec together so the test suite stays green throughout.

---

## Standard Stack

### Core (verified against actual repo files)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| evolved.lua | vendored in `lib/evolved.lua` (256KB) | ECS singleton — fragments, queries, spawn/destroy | Project-chosen ECS; all existing code uses it |
| binser | vendored in `lib/binser.lua` (26KB) | Lua value serialization for transport | Already integrated in transport.lua |
| busted | system install | Test framework — describe/it/before_each/after_each | Already configured in `.busted`, 135 tests passing |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| selene | system install | Lua linter | CI step 1; run `selene src/ main.lua conf.lua` |
| stylua | system install | Lua formatter (tabs, 120-col) | CI step 2; run `stylua --check src/ main.lua conf.lua` |

### Alternatives Considered

None — stack is fixed by prior decisions; all libraries are already vendored.

**Installation:** No installation needed — all libraries vendored in `lib/`.

---

## Architecture Patterns

### Existing Project Structure (verified)

```
src/
  core/
    bus.lua           Deferred-dispatch event bus — DONE, needs error_mode
    components.lua    Central fragment definitions — needs to ship empty
    context.lua       ctx factory — needs transport field + error_mode
    plugin_list.lua   Boot manifest — DONE, no changes needed
    registry.lua      Plugin registry — needs error_mode + side enforcement
    transport.lua     Thread channel transport — needs null stub + auto-bridge
    worlds.lua        ECS world factory — needs single-world mode
  plugins/            (empty — populated by games)
  client/             (empty — populated by games)
  server/             (empty — populated by games)
lib/
  evolved.lua         ECS engine
  binser.lua          Serializer
tests/
  core/               Spec files mirroring src/core/ (all exist, all pass)
  helpers/
    plugin_harness.lua  Isolation test helper
  canonical_plugin_spec.lua
  main_spec.lua
examples/
  canonical_plugin.lua  Reference plugin implementation
scripts/
  validate_architecture.lua
  full-check.sh
main.lua
```

### Pattern 1: Module-with-metatable (all existing core modules)

Every core module returns a table with `__index` set to itself, enabling `:method()` call syntax.

```lua
local Bus = {}
Bus.__index = Bus

function Bus.new(opts)
    return setmetatable({ ... }, Bus)
end

function Bus:method()
    -- self is the instance
end

return Bus
```

### Pattern 2: Injectable log function

Modules accept `opts.log` at construction time and default to `print`. This allows tests to capture log output without patching globals.

```lua
function Transport.new(opts)
    return setmetatable({
        _log = opts.log or print,
    }, Transport)
end
```

This pattern MUST be applied uniformly to Bus, Registry, Transport, and Context for error_mode integration.

### Pattern 3: Null object (for transport stub)

When `ctx.transport` is disabled, it MUST be a stub table with all the same method names as Transport — but all methods are no-ops. Plugins call `ctx.transport:mark_networkable("event")` without checking if transport exists.

```lua
-- Null transport stub
local NullTransport = {}
NullTransport.__index = NullTransport

function NullTransport.new()
    return setmetatable({}, NullTransport)
end

function NullTransport:mark_networkable(_event_name) end
function NullTransport:queue(_event_name, _data) end
function NullTransport:flush() end
function NullTransport:receive() return nil end
function NullTransport:receive_all() return {} end
function NullTransport:is_networkable(_event_name) return false end

return NullTransport
```

The stub can live in `src/core/transport.lua` as `Transport.Null` or in its own file `src/core/null_transport.lua`.

### Pattern 4: Config error_mode merging

Global default in `config.error_mode`, per-module overrides in `config.error_modes`. Each module resolves its effective mode at construction time:

```lua
local function resolve_error_mode(config, module_name, fallback)
    local modes = config and config.error_modes
    if modes and modes[module_name] ~= nil then
        return modes[module_name]
    end
    if config and config.error_mode ~= nil then
        return config.error_mode
    end
    return fallback
end
```

Modules call this during `new(opts)` to get their effective mode, then store it as `self._error_mode`. The two behaviors:
- `"strict"`: call `error(message)` — crashes
- `"tolerant"`: call `self._log(message)` — logs and continues

### Pattern 5: Worlds single/dual mode

`Worlds.create()` with no args = single-world mode (default). `Worlds.create({ dual = true })` = dual-world mode.

Single-world mode:
- Adds `worlds:spawn(components)` method — direct `evolved.spawn()` wrapper, no tags
- Makes `worlds:spawn_server()` and `worlds:spawn_client()` call `error()` immediately
- `worlds.server` and `worlds.client` are `nil` in single mode (or absent)

Dual-world mode (current behavior):
- Preserves `spawn_server()` and `spawn_client()` with ServerTag/ClientTag
- `worlds:spawn()` may be omitted or error with a hint to use `spawn_server`/`spawn_client`

### Pattern 6: Transport auto-bridge to bus

When transport is enabled, bus gains a post-flush hook that routes networkable events to transport. The bus does NOT need to know about transport directly — the bridge is installed by `Context.new()` after both objects are created:

```lua
-- In Context.new() when transport is enabled:
-- Install bridge: after every bus:flush(), push networkable events to transport
local original_flush = bus.flush
bus.flush = function(self_bus)
    original_flush(self_bus)
    transport:flush()
end

-- Bus handler that queues networkable events to transport on every emit
bus:on("*", function(event, data)  -- wildcard if bus supports it
    transport:queue(event, data)
end)
```

**Important:** The current Bus implementation does NOT support wildcard subscriptions or a pre-dispatch hook. The auto-bridge needs a different mechanism. Two options:

**Option A (recommended):** Override `bus:emit()` to also call `transport:queue()` for networkable events, then the transport flush happens after `bus:flush()`.

```lua
-- Bridge installed in Context.new():
local original_emit = bus.emit
bus.emit = function(self_bus, event, data)
    original_emit(self_bus, event, data)
    if transport:is_networkable(event) then
        transport:queue(event, data)
    end
end
```

**Option B:** Add a `_transport` field to Bus directly, checked during `emit()`. This couples Bus to Transport — avoid.

**Option A keeps Bus and Transport decoupled.** The bridge is installed at Context assembly time, not baked into either module.

### Anti-Patterns to Avoid

- **Global state outside ECS**: Any module-level mutable table (not the ECS world) that persists across ticks is a violation. Use `ctx` injection.
- **Requiring another plugin's internals**: `require("src.plugins.X.systems.Y")` from any other plugin or from core — forbidden. All cross-plugin communication is through the bus.
- **`evolved.id()` in plugin files**: Fragment IDs must come from `src/core/components.lua`. Any other call site is a violation (enforced by architecture validator in Phase 2).
- **`evolved.spawn()` in plugin files**: Plugins use `ctx.worlds:spawn()` / `ctx.worlds:spawn_server()` etc. Direct `evolved.spawn()` calls are not reachable from plugin code by design.
- **game logic in love.update or love.load**: All game logic goes in ECS systems. `main.lua` is wiring only.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Serialization | Custom serialize/deserialize | `lib/binser` (already integrated) | binser handles all Lua types including nested tables, metatables |
| ECS entity/component model | Custom ECS | `lib/evolved.lua` (already integrated) | evolved.lua is battle-tested; replacement = full rewrite |
| Topological sort | Custom dep graph | Use existing `registry.lua` (Kahn's BFS already there) | Already correct and tested |
| Test isolation | Love2D runtime mocking | Mock channels (already done in transport_spec.lua) | Injectable deps via constructor opts is the project pattern |

**Key insight:** The hard algorithms (topo sort, deferred dispatch, binser round-trip) are already implemented and tested. Phase 1 is wiring and extension, not rebuilding.

---

## Common Pitfalls

### Pitfall 1: evolved.lua is a global singleton
**What goes wrong:** Tests that spawn entities in one test pollute the ECS state for subsequent tests.
**Why it happens:** `evolved.lua` does not have per-instance worlds — all `evolved.spawn()` calls share a single global state.
**How to avoid:** Every test that spawns entities MUST clean up with `evolved.defer() / evolved.destroy(e) / evolved.commit()` in `after_each`. The existing test harness (`plugin_harness.teardown`) already implements this pattern.
**Warning signs:** Tests that pass alone but fail when run together; entity queries returning unexpected counts.

### Pitfall 2: Re-entrancy in bus:flush() with transport bridge
**What goes wrong:** If the auto-bridge calls `bus:emit()` inside a flush (e.g., when receiving inbound transport messages and re-emitting them), the re-entrancy guard discards the event.
**Why it happens:** `bus._flushing` is true during flush; any `emit()` during this window is blocked.
**How to avoid:** Inbound transport receive and re-emit should happen OUTSIDE the flush window — either before or after `bus:flush()` in the game loop. Document this in the integration point comment in `main.lua`.
**Warning signs:** Inbound transport messages silently discarded; warning logs about re-entrancy on expected events.

### Pitfall 3: components.lua ships with example fragments
**What goes wrong:** If `components.lua` ships with `Position`, `Velocity`, `Health` pre-defined, every game using the framework starts with those IDs consumed, and the tests for `components_spec.lua` assert those fields exist.
**Why it happens:** The file currently has example fragments; the decision is it should ship empty.
**How to avoid:** Clear `components.lua` to return an empty table. Update `components_spec.lua` to only assert the file returns a table (not specific fields). Update `canonical_plugin.lua` and `canonical_plugin_spec.lua` to define and use their own test components.
**Warning signs:** Games defining their own Position component conflict with the pre-allocated IDs from the framework.

### Pitfall 4: stylua and selene must pass on every change
**What goes wrong:** A code change that passes tests fails CI because of a formatting or lint issue.
**Why it happens:** selene is strict about undeclared variables; stylua enforces tabs + 120-col.
**How to avoid:** Run `scripts/full-check.sh` before committing any change. Never use spaces for indentation; always use tabs. Keep lines under 120 chars.
**Warning signs:** CI fails on lint/format step even though tests pass locally.

### Pitfall 5: worlds:spawn() in single-world mode vs evolved.spawn() confusion
**What goes wrong:** A plugin calls `evolved.spawn()` directly instead of `ctx.worlds:spawn()`, bypassing the worlds abstraction.
**Why it happens:** evolved.lua is a global; if a plugin `require("lib.evolved")`, it can call spawn directly.
**How to avoid:** The architecture validator (Phase 2) catches this. For Phase 1, the pattern is enforced by documentation and CLAUDE.md. `worlds:spawn()` is the only entry point from plugin code.
**Warning signs:** Architecture validator reports raw `evolved.spawn()` calls in plugin files.

### Pitfall 6: error_mode config not applied to existing modules
**What goes wrong:** Adding error_mode support to Registry or Bus but forgetting Services in Context, or not threading the config through Context.new().
**Why it happens:** Context is the assembly point; each module needs the config reference at construction time.
**How to avoid:** Context.new() must pass `config` to Bus.new(), and registry must receive config during boot or construction. Audit every module that has a `_log` field.
**Warning signs:** error_mode = "strict" is set globally but a module still logs-and-continues instead of crashing.

---

## Code Examples

Verified patterns from actual source files:

### Existing Bus re-entrancy guard (bus.lua, verified)

```lua
-- Source: src/core/bus.lua
function Bus:emit(event, data)
    if self._flushing then
        self._log("[Bus] Re-entrancy guard: emit('" .. event .. "') called during flush — discarded")
        return
    end
    table.insert(self._queue, { event, data })
end
```

### Existing Registry topological boot (registry.lua, verified)

```lua
-- Source: src/core/registry.lua
function Registry:boot(ctx)
    validate_deps(self._plugins)      -- fail-fast: missing deps
    local sorted = topological_sort(self._plugins)  -- Kahn's BFS; errors on cycle
    self._boot_order = sorted
    for _, entry in ipairs(sorted) do
        entry.module:init(ctx)
    end
    self._booted = true
end
```

### Existing reverse-order shutdown (registry.lua, verified)

```lua
-- Source: src/core/registry.lua
function Registry:shutdown(ctx)
    for i = #self._boot_order, 1, -1 do
        local entry = self._boot_order[i]
        if entry.module.shutdown then
            entry.module:shutdown(ctx)
        end
    end
end
```

### Existing Transport mock channel pattern (transport_spec.lua, verified)

```lua
-- Source: tests/core/transport_spec.lua
local function mock_channel()
    local items = {}
    return {
        push = function(_self, v) table.insert(items, v) end,
        pop  = function(_self) return table.remove(items, 1) end,
        getCount = function(_self) return #items end,
    }
end
```

### Existing plugin harness (tests/helpers/plugin_harness.lua, verified)

```lua
-- Source: tests/helpers/plugin_harness.lua
function plugin_harness.create_context(opts)
    opts = opts or {}
    local bus = Bus.new()
    local worlds = Worlds.create()
    local ctx = Context.new({ worlds = worlds, bus = bus, config = opts.config or {} })
    -- pre-register declared deps
    if opts.deps then ... end
    return ctx
end
```

### Current main.lua wiring gap

```lua
-- Source: main.lua — love.quit NOT connected to registry:shutdown()
-- Missing:
function love.quit()
    if _registry and _ctx then
        _registry:shutdown(_ctx)
    end
end
```

---

## What Needs to Change (Gap Analysis)

This is the authoritative delta between current state and Phase 1 success criteria:

### src/core/components.lua
- **Change:** Remove `Position`, `Velocity`, `Health` declarations — file ships empty (`return {}`)
- **Impact:** `canonical_plugin.lua` example must define its own test components; `components_spec.lua` must not assert specific fields

### src/core/worlds.lua
- **Change:** Add single-world mode support
  - `Worlds.create()` (no args) → single-world mode by default
  - `Worlds.create({ dual = true })` → current dual-world behavior
  - Single mode: add `worlds:spawn(components)` method; `spawn_server()` and `spawn_client()` call `error()`
  - Dual mode: current behavior unchanged; optionally add `worlds:spawn()` that errors with hint

### src/core/bus.lua
- **Change:** Add error_mode support
  - Accept `opts.error_mode` (or resolve from config) at `Bus.new()`
  - Tolerate handler errors in "tolerant" mode (already does `pcall`); in "strict" mode, re-raise

### src/core/transport.lua
- **Change 1:** Add null stub (`Transport.Null` or separate file)
- **Change 2:** No internal changes needed — auto-bridge is installed externally by Context

### src/core/context.lua
- **Change 1:** Add `transport` field to `ctx`
  - `opts.transport = nil/false` → `ctx.transport = NullTransport.new()` (null stub)
  - `opts.transport = true` → create `Transport.new()` with default channels, store as `ctx.transport`
  - `opts.transport = <instance>` → use provided instance as `ctx.transport`
- **Change 2:** Install auto-bridge: override `bus:emit()` to also call `transport:queue()` when transport is real
- **Change 3:** Pass config to modules for error_mode resolution

### src/core/registry.lua
- **Change:** Add error_mode support (strict = error propagates; tolerant = log and continue on init failure)
- **Optional:** Add side enforcement if `plugin.side` is declared

### main.lua
- **Change:** Add `love.quit()` callback that calls `registry:shutdown(ctx)`
- **Change:** Thread `transport` option through to `Context.new()`

### tests/core/components_spec.lua
- **Change:** Remove assertions for Position/Velocity/Health; assert only that the file returns a table

### tests/core/worlds_spec.lua
- **Change:** Add tests for single-world mode (`Worlds.create()` → `spawn()` works; `spawn_server()` errors)
- **Change:** Add tests for dual-world mode flag (`Worlds.create({ dual = true })` → old behavior)

### tests/core/context_spec.lua
- **Change:** Add tests for `ctx.transport` field (null stub when not configured; real instance when provided)

### tests/core/bus_spec.lua
- **Change:** Add tests for error_mode "strict" re-raise behavior (if spec changes)

### tests/main_spec.lua
- **Change:** Add test verifying `love.quit` calls `registry:shutdown`

### examples/canonical_plugin.lua
- **Change:** Must not use `Components.Position/Velocity/Health` if components.lua ships empty. Define local test fragments or accept that the example depends on game-defined components.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Dual-world always | Single-world as default, dual as opt-in | Phase 1 decision | Simpler onboarding for simple games |
| No transport field on ctx | ctx.transport always present (null stub if disabled) | Phase 1 decision | Plugins never need nil guard |
| components.lua ships with examples | components.lua ships empty | Phase 1 decision | Framework is genre-agnostic |
| No love.quit integration | love.quit calls registry:shutdown | Phase 1 gap | Proper teardown lifecycle |

---

## Open Questions

1. **How does the canonical_plugin example work after components.lua ships empty?**
   - What we know: `canonical_plugin.lua` currently requires `src.core.components` and uses `Components.Position`, `Components.Velocity`.
   - What's unclear: If components.lua is empty, the example breaks. Options: (a) define example-only fragments inside `canonical_plugin.lua` itself, (b) ship components.lua with example fragments but document they should be replaced, (c) remove the component usage from the example.
   - Recommendation: Option (a) — define local test fragments inside `canonical_plugin.lua` using `evolved.id(2)` directly, since that file is `examples/` (not a plugin). Update `canonical_plugin_spec.lua` accordingly. This satisfies "components.lua ships empty" while keeping the example useful.

2. **Bus error_mode: does "strict" re-raise inside pcall during flush?**
   - What we know: current Bus uses `pcall(list[j], data)` and logs errors. In "strict" mode the intent is to crash.
   - What's unclear: if flush re-raises, it aborts the flush mid-dispatch. Remaining handlers for that event won't fire.
   - Recommendation: In "strict" mode, remove `pcall` and let the error propagate naturally. Document that "strict" means a single bad handler aborts the entire flush — acceptable in dev mode.

3. **Transport auto-bridge: does the override of bus:emit() break the re-entrancy check?**
   - What we know: the re-entrancy guard checks `self._flushing` before queuing. The bridge calls `transport:queue()` which is a separate queue — no bus re-entrancy.
   - What's unclear: nothing — this is safe. `transport:queue()` does not call `bus:emit()`.
   - Recommendation: Confirmed safe. Document in code comments.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | busted (system install) |
| Config file | `.busted` (root — `ROOT = { "tests/" }`, `pattern = "_spec"`) |
| Quick run command | `busted tests/core/worlds_spec.lua` |
| Full suite command | `busted` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CORE-01 | Registry boots plugins in topo order via `plugin:init(ctx)` | unit | `busted tests/core/registry_spec.lua` | Yes |
| CORE-02 | Registry shuts down in reverse order via love.quit | unit + integration | `busted tests/main_spec.lua` | Yes (needs new test) |
| CORE-03 | Bus queues events during update, delivers on flush | unit | `busted tests/core/bus_spec.lua` | Yes |
| CORE-04 | Bus re-entrancy guard blocks emission during flush, logs warning | unit | `busted tests/core/bus_spec.lua` | Yes |
| CORE-05 | ECS world integrates evolved.lua with ServerTag/ClientTag isolation | unit | `busted tests/core/worlds_spec.lua` | Yes |
| CORE-06 | Single-world mode works — `Worlds.create()` default, `worlds:spawn()` | unit | `busted tests/core/worlds_spec.lua` | Yes (needs new tests) |
| CORE-07 | ctx = { worlds, bus, config, services, transport } passed to all plugins | unit | `busted tests/core/context_spec.lua` | Yes (needs transport tests) |
| CORE-08 | Components defined centrally, ships empty | unit | `busted tests/core/components_spec.lua` | Yes (needs update) |
| CORE-09 | Optional transport — null stub when disabled, auto-bridge when enabled | unit | `busted tests/core/transport_spec.lua` + `busted tests/core/context_spec.lua` | Yes (needs new tests) |
| CORE-10 | Explicit plugin manifest, no auto-discovery | unit | `busted tests/core/plugin_list_spec.lua` | Yes |

### Sampling Rate
- **Per task commit:** `busted tests/core/<module>_spec.lua` for the module being changed
- **Per wave merge:** `busted` (full suite)
- **Phase gate:** `scripts/full-check.sh` green (lint + format + tests + architecture validator)

### Wave 0 Gaps

The following test coverage does not yet exist and must be added as part of implementation:

- [ ] `tests/core/worlds_spec.lua` — add single-world mode tests (CORE-06)
- [ ] `tests/core/context_spec.lua` — add `ctx.transport` field tests (CORE-07, CORE-09)
- [ ] `tests/core/components_spec.lua` — remove specific-fragment assertions; assert only returns table (CORE-08)
- [ ] `tests/main_spec.lua` — add test for `love.quit` calling `registry:shutdown` (CORE-02)
- [ ] Transport null stub tests — either in `tests/core/transport_spec.lua` or `tests/core/context_spec.lua`

No new test files need to be created — existing spec files cover all modules. New tests are additions within existing files.

---

## Sources

### Primary (HIGH confidence)
- `src/core/bus.lua` — verified deferred dispatch, re-entrancy guard, injectable log, pcall handler errors
- `src/core/worlds.lua` — verified dual-world with ServerTag/ClientTag, evolved singleton pattern
- `src/core/registry.lua` — verified Kahn's BFS topo sort, fail-fast validation, reverse shutdown
- `src/core/context.lua` — verified ctx factory with Services sub-object; confirmed transport field is absent
- `src/core/transport.lua` — verified binser integration, mock channel pattern, networkable whitelist
- `src/core/components.lua` — verified ships with 3 example fragments (needs to be cleared)
- `main.lua` — verified love.quit is NOT connected to registry:shutdown (gap confirmed)
- `tests/core/*_spec.lua` (all 6 files) — verified 135 tests passing; identified coverage gaps
- `tests/helpers/plugin_harness.lua` — verified isolation pattern
- `.planning/phases/01-core-infrastructure/01-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)
- evolved.lua singleton behavior — inferred from worlds_spec.lua cleanup pattern (`evolved.defer` / `evolved.commit`)
- busted test patterns — inferred from existing spec files

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries verified as vendored in repo
- Architecture: HIGH — all modules read directly; gaps identified from source
- Pitfalls: HIGH — derived from actual code reading and test patterns in repo; not speculation
- Test map: HIGH — all spec files read; gaps confirmed by absence

**Research date:** 2026-03-01
**Valid until:** 2026-04-01 (stable tech stack; no moving parts)
