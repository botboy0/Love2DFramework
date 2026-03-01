# Phase 2: Core Infrastructure - Context

**Gathered:** 2026-03-01
**Status:** Ready for planning

<domain>
## Phase Boundary

The shared runtime that all future game plugins depend on: deferred-dispatch event bus, plugin registry with dependency enforcement, dual evolved.lua ECS worlds (server + client), love.thread channel transport for solo-mode client-server communication, and a canonical plugin example as the reference implementation. No game logic ships in this phase — only infrastructure.

</domain>

<decisions>
## Implementation Decisions

### Event Bus Behavior
- Deferred dispatch: events queue during the tick, flush at a defined point (end of update)
- Re-entrancy guard blocks handlers from emitting synchronously during flush
- Handler errors: log and continue — catch the error, log with stack trace, keep flushing remaining handlers. One broken handler does not break the tick.
- No priority levels — handlers fire in registration order
- No wildcard/pattern subscriptions — exact event name matching only

### Plugin Lifecycle
- Plugins declare dependencies explicitly; registry topologically sorts and enforces load order. Missing deps caught at boot, not runtime.
- `plugin:init(ctx)` fully implemented; `plugin:shutdown(ctx)` defined as a no-op stub in the interface (establishes the contract for future use)
- Plugin list defined in a Lua config table (e.g., `src/core/plugin_list.lua`) — explicit, lintable, no auto-discovery
- `ctx` exposes: world, bus, config, services

### Services
- `ctx.services` supports named service registration with fail-fast on missing/undeclared services at boot
- Convention enforcement: **services return data, events cause change**
  - Service providers must be stateless queries — no ECS mutations, no event emission internally
  - No service calls inside event handlers — keeps the two channels cleanly separated
- Architecture validator (`validate_architecture.lua`) checks convention compliance

### Dual ECS Worlds
- Shared component definitions between server and client worlds — one set of components, client adds render-only components on top (additive model)
- Event-driven sync: server world emits events on entity changes, client world listens and mirrors through the transport layer
- One world per system — systems run against either server or client world, never both. Cross-world data goes through events/transport.
- All component definitions live in `src/core/components/` — single source of truth, no per-plugin component definitions
- Thematic subfolders within `src/core/components/` as the component count grows (e.g., `physics/`, `combat/`)

### Transport Layer
- Message format: Lua tables serialized with binser (already needed for save/load per SAVE-01, one dependency for both)
- Flush once per tick, aligned with event bus flush — server systems run, events flush, transport sends batched messages to client
- Explicit opt-in for events to cross the boundary — events must be marked as "networkable" to be serialized and sent
- Channel backup handling: warn and keep going — log a warning if queue exceeds threshold, don't block or drop. In solo mode, backup indicates a bug. Cleanup/flow control deferred to a future phase.

### Claude's Discretion
- Exact binser serialization configuration
- love.thread channel naming conventions
- Event bus flush ordering relative to ECS system ticks
- Topological sort algorithm choice for plugin dependencies
- Warning threshold for channel backup detection
- Architecture validator implementation for service convention checks

</decisions>

<specifics>
## Specific Ideas

- Mindustry research informed the sync model: event-driven for discrete actions, with the understanding that factory games accept some desync for intermediate transport state and sync outputs instead
- Services should fail with clear messages: "Service 'X' not found — did plugin 'Y' forget to declare dependency on 'Z'?"
- The canonical plugin example should demonstrate the full lifecycle: init with ctx, component registration, system registration, event handling, service usage, and the shutdown no-op stub

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/helpers/plugin_harness.lua`: Stub world/bus/registry for testing — needs upgrading to real implementations in Phase 2 while keeping the same interface
- `examples/canonical_plugin.lua`: Placeholder with init stub — gets fully implemented as the reference
- `scripts/validate_architecture.lua`: Working validator — extend with service convention checks

### Established Patterns
- Plugin init signature: `plugin:init(ctx)` where `ctx = { world, bus, config, services }` (documented in CLAUDE.md)
- Absolute dot-notation requires (CLAUDE.md enforced)
- Architecture validator runs in CI pipeline (step 4)

### Integration Points
- `main.lua`: Currently empty love callbacks — will delegate to plugin registry boot sequence
- `src/core/`: Empty directory — all new infrastructure lands here (bus, registry, transport)
- `src/plugins/`: Empty directory — canonical plugin example will be the first real plugin
- `lib/`: No vendored libraries yet — evolved.lua and binser need to be added

</code_context>

<deferred>
## Deferred Ideas

- Transport layer cleanup/flow control for channel backup — future phase when multiplayer approaches
- Shutdown orchestration in the registry (calling shutdown in reverse dependency order) — add when save/load or resource cleanup needs it
- Event priority levels — revisit if a concrete need emerges
- Wildcard event subscriptions — revisit if event proliferation becomes a pain point

</deferred>

---

*Phase: 02-core-infrastructure*
*Context gathered: 2026-03-01*
