# CLAUDE.md — FactoryGame Architectural Rules

This file defines the architectural rules Claude must follow when generating code for FactoryGame. Style enforcement (formatting, linting) is delegated to stylua and selene — this document covers architectural rules those tools cannot enforce.

---

## Project Overview

FactoryGame is a top-down pixel art factory/survival game built with Love2D (Lua). It uses an ECS-first architecture with event-driven communication between systems, organized as self-contained feature plugins.

**Tech stack:** Love2D, Lua, evolved.lua (ECS), busted (testing), selene (linting), stylua (formatting)

---

## Single Source of Truth

This is the top-level project principle:

- **Game state lives in the ECS world, nowhere else.** No copies of game state in plugin fields, globals, or local variables that outlive a frame.
- **Rules and templates live in one place.** CLAUDE.md references `examples/canonical_plugin.lua` — it does not inline the template. Source of truth is the file.
- **No duplicated state across plugins.** If two plugins need the same data, one owns it and exposes it through the event bus.

Violate this principle only when technically impossible to implement otherwise, and document the exception explicitly.

---

## Architectural Rules

### 1. All game logic MUST live in ECS systems

The ECS world is the only place where game state is modified. Systems process components and emit events. No logic lives in `love.update`, plugin `init`, or helper modules.

**Do this:**

```lua
-- src/plugins/movement/systems/movement_system.lua
local MovementSystem = {}

function MovementSystem:update(world, _dt)
	-- Query entities with Position and Velocity components
	for _id, position, velocity in world:query(Position, Velocity) do
		position.x = position.x + velocity.dx * _dt
		position.y = position.y + velocity.dy * _dt
	end
end

return MovementSystem
```

**Don't do this:**

```lua
-- main.lua or anywhere outside a system
function love.update(dt)
	-- BAD: game logic outside ECS
	player.x = player.x + player.speed * dt
end
```

---

### 2. All inter-system communication MUST go through the event bus

Systems communicate by emitting and subscribing to events. No system calls another system's functions directly. No direct references to other plugins.

**Do this:**

```lua
-- Emit an event when a resource is collected
function HarvestSystem:update(world, _dt)
	for id, harvester, resource in world:query(Harvester, Resource) do
		if harvester.progress >= 1.0 then
			-- Notify other systems via the bus
			self.bus:emit("resource_collected", { entity = id, resource = resource.type, amount = 1 })
			world:remove(id, Resource)
		end
	end
end

-- Another system subscribes to the event
function InventorySystem:init(ctx)
	ctx.bus:on("resource_collected", function(data)
		-- Add to inventory
	end)
end
```

**Don't do this:**

```lua
-- BAD: direct cross-system call
function HarvestSystem:update(world, _dt)
	local inventory_system = require("src.plugins.inventory.systems.inventory_system")
	inventory_system:add_item(player_id, resource_type)
end
```

---

### 3. Each plugin is a directory with `init.lua`

Plugins register components, systems, and event handlers through a standard `plugin:init(ctx)` API where `ctx = { world, bus, config, services }`.

**Do this:**

```lua
-- src/plugins/movement/init.lua
local MovementPlugin = {}

function MovementPlugin:init(ctx)
	self.world = ctx.world
	self.bus = ctx.bus

	-- Register ECS components
	-- ctx.world:register(PositionComponent)

	-- Register ECS systems
	-- ctx.world:add_system(MovementSystem)

	-- Register event handlers
	-- ctx.bus:on("player_moved", self.on_player_moved)
end

return MovementPlugin
```

See `examples/canonical_plugin.lua` for the complete reference template.

**Don't do this:**

```lua
-- BAD: flat file plugin (no directory, no init.lua)
-- src/plugins/movement.lua
local M = {}
function M.setup() ... end
return M
```

---

### 4. No plugin may access another plugin's internals

Plugins are isolated modules. A plugin may only interact with other plugins through the event bus. Internal files (`systems/`, `components/`) are private to the plugin.

**Do this:**

```lua
-- Communicate through events
ctx.bus:emit("crafting_started", { recipe = recipe_id })
```

**Don't do this:**

```lua
-- BAD: reaching into another plugin's internals
local CraftingHelper = require("src.plugins.crafting.helpers.craft_helper")
```

---

### 5. No global mutable state outside the ECS world

The selene linter (configured with `unscoped_variables = "deny"`) catches undeclared globals. The following globals are whitelisted in `love2d.yml` because they are framework-provided or ECS context:

- `love` — Love2D framework
- `world` — ECS world instance
- `eventBus` — shared event bus
- `registry` — plugin registry

Any other global is a violation. Use `local` variables or pass state through `ctx`.

**Do this:**

```lua
local MyModule = {}
local internal_state = {}  -- local, not global
return MyModule
```

**Don't do this:**

```lua
-- BAD: implicit global
player_score = 0  -- no 'local', creates a global
```

---

## Naming Conventions

| Type | Convention | Example |
|------|-----------|---------|
| Files | `snake_case` | `movement_system.lua` |
| Variables | `snake_case` | `local tile_count = 0` |
| Classes/Modules | `PascalCase` | `MovementSystem`, `InventoryPlugin` |
| Events | `snake_case` | `"resource_collected"`, `"player_died"` |
| Components | `PascalCase` | `Position`, `Velocity`, `Health` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_INVENTORY_SIZE = 64` |

**Require paths:** Always use absolute dot-notation paths. Never use relative requires.

```lua
-- Do this
local Bus = require("src.core.bus")

-- Don't do this
local Bus = require("../core/bus")
local Bus = require("./bus")
```

---

## File Organization

```
src/
  core/          Shared infrastructure (event bus, plugin registry, ECS utilities)
  plugins/       Feature plugins — each a directory with init.lua
  client/        Client-only code (rendering, input, UI) — no game logic
  server/        Server-only code (simulation tick, world gen) — no rendering

lib/             Vendored third-party libraries (excluded from lint/format)
tests/           Mirrors src/ structure — every src/ .lua has a _spec.lua here
  helpers/       Shared test utilities (plugin_harness.lua, etc.)
assets/          Sprites, audio, data files
examples/        Reference implementations (canonical_plugin.lua)
conf.lua         Love2D configuration
main.lua         Love2D entry point (delegates to plugins, no game logic here)
```

**Rules:**
- `src/client/` must not contain game logic — only rendering and input handling
- `src/server/` must not contain rendering code — only simulation
- `lib/` is excluded from selene and stylua checks (vendored code)
- `examples/` contains reference implementations only — not loaded at runtime

---

## Plugin Template

The canonical plugin example lives at `examples/canonical_plugin.lua`. Reference it for the complete plugin structure, including how to register components, systems, and event handlers.

Do NOT copy-paste the template inline — require the examples/ file or follow its pattern. The single source of truth is the file.

---

## Testing Rules

- Every `src/` file must have a corresponding `tests/` `_spec.lua` file (enforced by the architecture validator)
- Use `tests/helpers/plugin_harness.lua` for plugin isolation testing — it sets up a minimal context with declared dependencies only
- Plugins must declare their dependencies explicitly; undeclared dependencies are architectural violations
- Tests must be meaningful — no coverage-metric-chasing empty specs

**Test file naming:**

```
src/plugins/movement/systems/movement_system.lua
tests/plugins/movement/systems/movement_system_spec.lua
```

---

## What Tools Enforce

| Tool | Enforces |
|------|---------|
| `selene` | Undeclared globals, unused variables, type errors |
| `stylua` | Formatting (tabs, 120-col, quote style) |
| `validate_architecture.lua` | Cross-plugin imports, game logic outside ECS, missing test files |
| `busted` | Unit and integration test correctness |

CLAUDE.md covers architectural rules that static analysis cannot catch — conceptual violations like "using a global that was declared but shouldn't be shared" or "putting business logic in the wrong layer."
