# Architecture Patterns

**Project:** FactoryGame (Love2D)
**Domain:** ECS-based factory/survival game with plugin architecture and devops enforcement
**Researched:** 2026-03-01
**Confidence:** MEDIUM

---

## Recommended Architecture

### High-Level Topology

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT PROCESS                       │
│                                                         │
│  ┌──────────┐   events    ┌──────────────────────────┐  │
│  │  Input   │────────────►│       Event Bus          │  │
│  │  Layer   │             │  (client-side signals)   │  │
│  └──────────┘             └──────────┬───────────────┘  │
│                                      │                  │
│  ┌───────────────────────────────────▼───────────────┐  │
│  │               Client ECS World                    │  │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────────┐  │  │
│  │  │ Render   │  │ Predict  │  │  Plugin        │  │  │
│  │  │ Systems  │  │ Systems  │  │  Systems       │  │  │
│  │  └──────────┘  └──────────┘  └────────────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
│                           │ love.thread channel         │
└───────────────────────────┼─────────────────────────────┘
                            │ (binary packets via bitser)
┌───────────────────────────▼─────────────────────────────┐
│                    SERVER PROCESS                       │
│                  (love.thread / ENet)                   │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │               Server ECS World                   │   │
│  │  ┌──────────┐  ┌──────────┐  ┌────────────────┐ │   │
│  │  │ Physics  │  │ World    │  │  Plugin        │ │   │
│  │  │ Systems  │  │ Systems  │  │  Systems       │ │   │
│  │  └──────────┘  └──────────┘  └────────────────┘ │   │
│  └──────────────────────────────────────────────────┘   │
│                           │                             │
│  ┌────────────────────────▼──────────────────────────┐  │
│  │               Server Event Bus                    │  │
│  └───────────────────────────────────────────────────┘  │
│                           │                             │
│  ┌────────────────────────▼─────────────────────────┐   │
│  │          World / Chunk Manager                   │   │
│  │  (procedural gen, load/unload, spatial index)    │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Process Boundary: Server is Authoritative

- Server owns ALL game state. Client is a thin, stateless renderer plus local prediction.
- Solo play: server runs in love.thread. Packets flow over love.thread channels.
- Multiplayer: server runs as separate process. Packets flow over ENet.
- Client ECS world is a projection of server state — rendering and prediction only.

---

## Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **Bootstrap / main.lua** | love.load/update/draw wiring | Plugin Registry, Client ECS |
| **Plugin Registry** | Loads plugins in order, calls plugin:init(ctx) | All plugins, ECS Worlds, Event Bus |
| **Event Bus (client)** | Typed event dispatch | Client systems, plugins, Input Layer |
| **Event Bus (server)** | Same API, isolated instance | Server systems, plugins, Network Layer |
| **Client ECS World** | Rendering components, local prediction | Client systems, Event Bus |
| **Server ECS World** | All authoritative game state | Server systems, Event Bus, World Manager |
| **World / Chunk Manager** | Chunk load/unload, procedural gen | Server ECS World, Server Event Bus |
| **Network Layer** | Serialization, packet routing | Client Bus, Server Bus |
| **Input Layer** | baton input → typed events | Client Event Bus |
| **Render Layer** | SpriteBatch, draw calls, Push resolution | Client ECS World |

---

## Data Flow

### Game Loop (Server Tick)

```
love.update(dt)
  └─► Server tick via love.thread channel
        └─► Server ECS World processes systems
              └─► Systems query components, mutate state
              └─► Systems emit events to Server Event Bus
        └─► Server Event Bus dispatches to subscribers
              └─► Network Layer serializes state snapshots
              └─► Client receives snapshot via channel
```

### Input → Action (Client)

```
baton:update()
  └─► Input Layer detects action
  └─► Emits typed event to Client Event Bus
        └─► Client ECS Prediction System applies local move
        └─► Network Layer sends input command to Server
              └─► Server validates, applies authoritative result
              └─► Server sends correction if diverged
```

### Plugin Registration

```
PluginRegistry:load("player")
  └─► require("plugins.player")
  └─► plugin:init(ctx)
        └─► ctx.world:component("position", {...})
        └─► ctx.world:system(movementSystem, ...)
        └─► ctx.bus:on("player.died", handler)
  └─► registry:register("player", plugin)
```

### Persistence (ECS-First)

```
Save: Server ECS World → binser serialize → file
Load: file → binser deserialize → Server ECS World repopulated
```

---

## Patterns to Follow

### Pattern 1: Plugin Registration API

```lua
-- plugins/player/init.lua
local M = {}

function M:init(ctx)
  -- Register components
  self.position = ctx.world:component("position")
  self.velocity = ctx.world:component("velocity")

  -- Register systems
  ctx.world:system(require("plugins.player.systems.movement"), self.position, self.velocity)

  -- Subscribe to events
  ctx.bus:on("input.move", function(e) self:onMove(e) end)
end

return M
```

### Pattern 2: Deferred-Dispatch Event Bus

```lua
local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
  return setmetatable({ handlers = {}, queue = {}, flushing = false }, EventBus)
end

function EventBus:on(event, handler)
  self.handlers[event] = self.handlers[event] or {}
  table.insert(self.handlers[event], handler)
end

function EventBus:emit(event, data)
  table.insert(self.queue, { event = event, data = data })
end

function EventBus:flush()
  assert(not self.flushing, "Re-entrant flush detected!")
  self.flushing = true
  while #self.queue > 0 do
    local batch = self.queue
    self.queue = {}
    for _, msg in ipairs(batch) do
      local list = self.handlers[msg.event]
      if list then
        for _, h in ipairs(list) do h(msg.data) end
      end
    end
  end
  self.flushing = false
end

return EventBus
```

### Pattern 3: Context Object

```lua
-- All plugins receive the same ctx
local ctx = {
  world = evolved.new(),
  bus = EventBus.new(),
  config = require("config"),
  services = {}
}
```

### Pattern 4: selene Enforcement

```toml
# selene.toml
std = "love+game"
[rules]
global_usage = "deny"
```

Custom `selene_defs/game.yml` declares only allowed globals.

### Pattern 5: Plugin Isolation Test

```lua
-- spec/plugins/player_spec.lua
describe("player plugin", function()
  local ctx
  before_each(function()
    ctx = {
      world = evolved.new(),
      bus = EventBus.new(),
      services = {}
    }
    require("plugins.core"):init(ctx)
    require("plugins.player"):init(ctx)
  end)

  it("registers movement system", function()
    -- verify system registered
  end)
end)
```

---

## Anti-Patterns to Avoid

| Anti-Pattern | What | Instead |
|-------------|------|---------|
| Logic outside ECS | Game logic in callbacks, helpers | Event handlers set component flags; systems read them |
| Direct plugin imports | `require("plugins.other")` | Communicate only via event bus |
| Global mutable state | Module-level tables accumulating state | All state in ECS components |
| Monolithic systems | One system file handling multiple concerns | One file per system, single responsibility |
| Client-side game logic | Damage calc, crafting on client | Client emits inputs only; server simulates |

---

## Suggested Build Order

```
Layer 0: DevOps Foundation
  selene + stylua config
  busted test runner
  pre-commit hooks
  GitHub Actions CI
  CLAUDE.md with architectural rules
  ↓ GATE: all checks green

Layer 1: Core Infrastructure
  EventBus (deferred dispatch, re-entrancy guard)
  PluginRegistry
  evolved.lua world factories (client + server)
  love.thread channel transport
  Context object (ctx)
  ↓

Layer 2: Core Plugin
  Base components (Position, Velocity, Health, Inventory)
  Canonical plugin example
  Plugin isolation test template
  ↓

Layer 3: World Infrastructure
  Chunk Manager (server-side)
  Procedural world gen (server-side)
  Tile components + SpriteBatch renderer (client)
  ↓

Layer 4: Player Plugin
  Player entity, movement system (server + client prediction)
  Input Layer → Event Bus (baton)
  Camera (gamera)
  ↓

Layer 5-7: Game Features (Survival, Crafting, Combat)
  Each as isolated plugin following the canonical pattern
```

**Ordering rationale:** DevOps first because architectural drift was the primary failure. Core infrastructure before plugins because plugins are injected with ctx. World before player because spawning needs a chunk.

---

*Architecture research complete: 2026-03-01*
