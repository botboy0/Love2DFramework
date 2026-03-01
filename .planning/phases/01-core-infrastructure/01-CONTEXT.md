# Phase 1: Core Infrastructure - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

The complete framework contract: event bus, ECS worlds, plugin registry, context object, and optional transport. A developer can register a plugin and have it receive a working `ctx` with a live event bus and ECS world. No feature plugins, no validation tooling, no developer tools — just the core objects and their contracts.

</domain>

<decisions>
## Implementation Decisions

### Single-world mode
- Activated via flag on `Worlds.create()` — e.g. `Worlds.create({ single = true })`
- Single-world is the **default** — calling `Worlds.create()` with no args gives single-world mode
- Dual-world (server/client tags) is opt-in
- In single-world mode, `spawn_server()` and `spawn_client()` **error** if called — forces developers to use `spawn()`
- Plugin side declarations (`side = "server"` / `side = "client"`) are **optional** on the plugin manifest
  - If declared, the registry enforces it (server plugin can't depend on client plugin, etc.)
  - If omitted, plugin gets full `ctx` with access to both worlds
  - Single-world mode ignores side declarations

### Transport-bus wiring
- **Auto-bridge**: when transport is enabled, the bus automatically forwards any event marked as networkable to transport — plugins just call `bus:emit()` as normal
- **Layered opt-in**: one field, two modes
  - `transport = true` → framework creates Transport with sensible default channels, wires to bus
  - `transport = Transport.new({...})` → framework uses the provided instance, just wires to bus
  - `transport = nil/false` → no transport
- Plugins mark their own events as networkable during init via `ctx.transport:mark_networkable("event_name")`
- **Null object pattern**: if transport is disabled, `ctx.transport` is a stub with no-op methods — plugins never need to guard with `if ctx.transport then`. Architecture validator (Phase 2) will catch "marking events networkable but transport isn't enabled."

### Component ownership
- All components defined centrally in `src/core/components.lua` — no `evolved.id()` calls in plugin files
- The file ships **empty** — each game defines its own components; framework doesn't prescribe which ones
- **Flat table** structure — just `Components.X, Components.Y = evolved.id(2)`, no grouping or sub-tables
- No runtime guard against `evolved.id()` outside components.lua — CLAUDE.md rule + architecture validator (Phase 2) is sufficient enforcement

### Error philosophy
- **Config-driven error modes** with global default and per-module overrides:
  ```lua
  config = {
      error_mode = "strict",  -- global default
      error_modes = {         -- per-module overrides
          bus = "tolerant",
          registry = "strict",
      }
  }
  ```
- **Two levels only**: `strict` (crash on error) and `tolerant` (log and continue)
- No `silent` mode — logging is cheap, suppressing hides real problems. Pass a no-op log function if truly needed.
- **Sensible defaults** (used when no config provided):
  - `registry` → strict (broken boot = crash)
  - `services` → strict (missing service = broken contract)
  - `bus` → tolerant (one bad handler shouldn't kill the game)
  - `transport` → tolerant (warn on issues, don't crash)
- Typical workflow: developer sets global `error_mode = "strict"` during development, uses defaults or `"tolerant"` for release

### Claude's Discretion
- Exact implementation of the null transport stub
- How `Worlds.create()` flag is named internally (single/dual/mode)
- Default channel names for `transport = true` mode
- How config error_modes merge (global first, module override wins)

</decisions>

<specifics>
## Specific Ideas

- World mode flag should feel like a light switch — one value changes the behavior, everything else adapts
- Transport layering inspired by the boolean-or-instance pattern — `true` means "do it for me," instance means "I did it myself"
- Error config should work like logging levels — set it once globally, override where needed

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bus.lua`: Fully implemented deferred-dispatch bus with re-entrancy guard, on/off/emit/flush — needs error_mode integration
- `worlds.lua`: Dual-world with ServerTag/ClientTag via evolved.id() — needs single-world mode and flag
- `registry.lua`: Topological sort boot, reverse-order shutdown, fail-fast validation — needs optional side enforcement and error_mode
- `context.lua`: ctx factory with Services sub-object — needs transport field and config-driven error modes
- `transport.lua`: binser serialization, networkable whitelist, queue+flush — needs null stub variant and auto-bridge to bus
- `components.lua`: 3 example fragments — needs to ship empty
- `plugin_list.lua`: Empty manifest, ready to use
- `main.lua`: Wires load/update/draw but `love.quit` not connected to `registry:shutdown()`

### Established Patterns
- Deferred dispatch (bus queue + flush) — transport already mirrors this pattern
- Fail-fast validation (registry validates before any init runs)
- Injectable dependencies (bus accepts custom log function)
- Module-level constants (Worlds.ServerTag/ClientTag defined once)

### Integration Points
- `main.lua:love.load()` — where worlds, bus, context are created; needs flag/transport wiring
- `main.lua:love.quit()` — missing; needs to call `registry:shutdown(ctx)`
- `bus:flush()` in `love.update()` — transport flush should happen alongside or after bus flush
- `Context.new()` — entry point for config, transport, and error mode injection

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-core-infrastructure*
*Context gathered: 2026-03-01*
