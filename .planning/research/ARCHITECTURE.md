# Architecture Research

**Domain:** Love2D Game Framework
**Researched:** 2026-03-01
**Confidence:** HIGH — architecture is already implemented in the codebase. All findings from source files.

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Example Game (Layer 6)                    │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ Plugin  │  │ Plugin  │  │ Plugin  │  │ Plugin  │        │
│  │  (move) │  │ (input) │  │(render) │  │ (asset) │        │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
│       │            │            │            │              │
├───────┴────────────┴────────────┴────────────┴──────────────┤
│                   Plugin Registry (Layer 4)                   │
│              plugin_list.lua + registry.lua                   │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  context.lua │  │transport.lua │  │  (services)  │       │
│  │  DI container│  │channel bridge│  │   optional   │       │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘       │
│         │                 │           Layer 3                 │
├─────────┴─────────────────┴─────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐                          │
│  │   bus.lua    │  │  worlds.lua  │   Layer 2                │
│  │deferred queue│  │tag-based dual│                          │
│  └──────────────┘  └──────────────┘                          │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐                                            │
│  │components.lua│   Layer 1 — Fragment IDs                   │
│  └──────────────┘                                            │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐                          │
│  │ evolved.lua  │  │  binser.lua  │   Layer 0 — Vendored    │
│  └──────────────┘  └──────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Status |
|-----------|----------------|--------|
| `main.lua` | Love2D entry; no game logic; delegates to Registry; flushes Bus | Exists (needs wiring) |
| `registry.lua` | Topological boot + reverse shutdown of plugins | To build |
| `context.lua` | DI container: `{ worlds, bus, config, services }` | To build |
| `worlds.lua` | Dual-world via ServerTag/ClientTag on evolved singleton | To build |
| `bus.lua` | Deferred queue; flush-per-tick; re-entrancy guard | To build |
| `transport.lua` | love.thread channel bridge; binser serialization | To build |
| `components.lua` | Single source of truth for fragment IDs | To build |
| `plugin_list.lua` | Explicit boot manifest | To build |
| `plugins/<name>/init.lua` | Feature units; isolated via bus+services | To build |
| `validate_architecture.lua` | Static enforcement in CI | Done |

## Recommended Project Structure

```
src/
├── core/               # Framework infrastructure (bus, registry, worlds, context)
│   ├── bus.lua         # Deferred-dispatch event bus
│   ├── registry.lua    # Plugin registry with dependency sort
│   ├── context.lua     # DI container passed to all plugins
│   ├── worlds.lua      # Dual ECS world management
│   ├── transport.lua   # love.thread channel bridge
│   └── components.lua  # Shared fragment ID definitions
├── plugins/            # Feature plugins — each a directory with init.lua
│   └── <name>/
│       ├── init.lua    # Plugin entry: registers components, systems, handlers
│       ├── systems/    # ECS systems (private to plugin)
│       └── components/ # Plugin-specific components (private to plugin)
├── client/             # Client-only code (rendering, input, UI) — no game logic
└── server/             # Server-only code (simulation) — no rendering

lib/                    # Vendored third-party libraries
tests/                  # Mirrors src/ structure
  └── helpers/          # plugin_harness.lua, test utilities
examples/               # Reference implementations + example game
  └── canonical_plugin.lua
```

### Structure Rationale

- **src/core/:** Framework internals that all plugins depend on. Changes here affect everything.
- **src/plugins/:** Isolated feature modules. Each is a directory with init.lua. No cross-plugin requires.
- **src/client/ and src/server/:** Separation enforced by architecture validator — client has no game logic, server has no rendering.
- **lib/:** Vendored libraries excluded from lint/format.

## Architectural Patterns

### Pattern 1: Deferred Event Bus

**What:** Events emitted during update() are queued; they dispatch only when bus:flush() is called at end of tick.
**When to use:** All inter-system communication.
**Trade-offs:** Prevents cascading event chains within a tick (good for determinism), but handlers see events one tick late.

**Example:**
```lua
-- System emits during update
function HarvestSystem:update(world, dt)
    self.bus:emit("resource_collected", { type = "copper", amount = 1 })
end

-- main.lua flushes at end of tick
function love.update(dt)
    registry:update(dt)
    bus:flush()  -- all queued events dispatch now
end
```

### Pattern 2: Tag-Based World Isolation

**What:** evolved.lua is a global singleton. Server/client separation via ServerTag/ClientTag fragments on entities, with scoped queries.
**When to use:** Client-server architecture (optional — single-world games skip tags).
**Trade-offs:** Simpler than two separate ECS instances, but requires discipline to always scope queries.

### Pattern 3: Plugin Context Injection

**What:** Single `ctx = { worlds, bus, config, services }` object passed to all plugins via `plugin:init(ctx)`.
**When to use:** Every plugin initialization.
**Trade-offs:** Clean dependency injection, easy to test (mock ctx), but all plugins see the same interface.

## Data Flow

### Game Loop Flow

```
love.update(dt)
    ↓
registry:update(dt)  →  plugin1:update(dt)  →  plugin2:update(dt)
    ↓                         ↓                       ↓
                        emit events              emit events
    ↓
bus:flush()  →  deliver queued events to subscribers
    ↓
love.draw()
    ↓
registry:draw()  →  client plugins render from ECS state
```

### Client-Server Flow (Optional)

```
[Client World]                    [Server World]
    ↓ (input)                          ↑
transport:send(input)  ──channel──→  transport:receive()
    ↑                                  ↓
transport:receive()  ←──channel──  transport:send(state)
    ↓ (render from state)
```

### Key Data Flows

1. **Plugin communication:** Plugin A emits event → bus queues → bus:flush() → Plugin B handler fires
2. **ECS queries:** System queries world for entities with specific components → processes them → modifies components in-place
3. **Client-server sync:** Client sends input via transport → server processes → server sends state delta via transport → client applies

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Simple game (1 world) | Skip transport, skip ServerTag/ClientTag, single world |
| Complex game (dual world) | Enable transport, tag entities, separate simulation from rendering |
| Multiplayer | Replace love.thread transport with ENet, same bus/plugin architecture |

### Scaling Priorities

1. **First bottleneck:** Draw calls — batch with SpriteBatches, spatial culling
2. **Second bottleneck:** ECS query performance — evolved.lua chunk storage handles this well

## Anti-Patterns

### Anti-Pattern 1: Cross-Plugin Requires

**What people do:** `require("src.plugins.crafting.helpers.craft_helper")` from another plugin
**Why it's wrong:** Tight coupling, untestable in isolation, violates plugin boundaries
**Do this instead:** Communicate through bus events only

### Anti-Pattern 2: Game Logic in main.lua

**What people do:** Put update logic in `love.update()` directly
**Why it's wrong:** Bypasses ECS, untestable, creates implicit global state
**Do this instead:** All logic in ECS systems registered by plugins

### Anti-Pattern 3: Emitting During Flush

**What people do:** Event handler emits another event (re-entrant emit)
**Why it's wrong:** Unpredictable ordering, potential infinite loops
**Do this instead:** Re-entrancy guard blocks it; queue follow-up events for next tick

### Anti-Pattern 4: Caching ECS State in Plugin Fields

**What people do:** Store component values in plugin local variables across ticks
**Why it's wrong:** Stale data — ECS is the single source of truth
**Do this instead:** Query ECS every tick

### Anti-Pattern 5: Auto-Discovery of Plugins

**What people do:** Scan directories to find and load plugins automatically
**Why it's wrong:** Creates untestable permutations, order-dependent bugs
**Do this instead:** Explicit `plugin_list.lua` manifest

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Plugin ↔ Plugin | Event bus only | CI enforces no cross-requires |
| Plugin ↔ ECS | Direct query/mutation via ctx.worlds | Components are shared fragments |
| Client ↔ Server | Transport channels | Optional; same-process via love.thread |
| Plugin ↔ Framework | ctx object (worlds, bus, config, services) | Standard init(ctx) API |

## Build Order (Dependency Layers)

```
Layer 0: evolved.lua, binser.lua          (vendored — done)
Layer 1: components.lua                   (fragment IDs)
Layer 2: bus.lua, worlds.lua              (event queue, tag worlds)
Layer 3: context.lua, transport.lua       (injection container, channel bridge)
Layer 4: registry.lua, plugin_list.lua    (plugin boot)
Layer 5: src/plugins/<name>/init.lua      (feature plugins — asset, input)
Layer 6: examples/<game>/                 (example game)
```

## Sources

- Direct codebase analysis of Love2DFramework repository
- FactoryGame .planning/ documentation (origin project)
- evolved.lua ECS patterns
- Love2D threading and channel documentation

---
*Architecture research for: Love2D Game Framework*
*Researched: 2026-03-01*
