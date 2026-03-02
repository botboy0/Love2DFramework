--- Canonical Plugin Example
--- Reference implementation for all game plugins.
--- Demonstrates: init with ctx, component usage, system query, event handling,
--- service registration, and shutdown stub.
---
--- This plugin works in both single-world and dual-world modes:
---   - Single-world (Worlds.create()): query covers the entire world.
---   - Dual-world (Worlds.create({ dual = true })): query scoped to server world via tag.
---
--- Component fragments are defined locally here because examples/ is a self-contained
--- reference — not loaded at runtime. In a real game, fragments live in
--- src/core/components.lua and are shared across plugins. The canonical plugin
--- defines its own for demonstration purposes only.
---
--- All future plugins follow this pattern. See CLAUDE.md for architectural rules.
---
--- NOTE: examples/ is NOT loaded at runtime — this is a reference only.

local evolved = require("lib.evolved")

local CanonicalPlugin = {}

--- Plugin metadata
CanonicalPlugin.name = "canonical"
CanonicalPlugin.deps = {} -- no external dependencies for the example

--- Example-only component fragments.
--- In a real game, these would be defined in src/core/components.lua.
--- The canonical plugin defines its own for demonstration purposes only.
--- Exposed on the module table so tests can spawn entities with the correct fragments.
CanonicalPlugin.Position, CanonicalPlugin.Velocity = evolved.id(2)
local Position = CanonicalPlugin.Position
local Velocity = CanonicalPlugin.Velocity

--- Initialize the plugin.
--- Called by the plugin registry during boot in dependency order.
--- @param ctx table { worlds, bus, config, services, transport }
function CanonicalPlugin:init(ctx)
	self.bus = ctx.bus
	self.worlds = ctx.worlds

	-- 0. Config access — read framework/game configuration values.
	-- ctx.config is the plain table passed through Context.new().
	-- Games set values in _config in main.lua or override via conf.lua.
	local _tick_rate = ctx.config.tick_rate or 60 -- unused in example; demonstrates pattern

	-- 1. Component usage — each game defines fragment IDs in components.lua.
	-- Plugins import and use those shared fragments. This example defines its own
	-- to remain self-contained. In a real game: local C = require("src.core.components")
	-- then use C.Position, C.Velocity, etc.

	-- 2. System query — build a query for entities with Position + Velocity.
	-- In dual-world mode, scope query to server world via its tag.
	-- In single-world mode (ctx.worlds.server is nil), build without a world tag.
	local builder = evolved.builder():include(Position, Velocity)
	if ctx.worlds.server then
		builder:include(ctx.worlds.server.tag)
	end
	self._movement_query = builder:build()

	-- 3. Event handling — subscribe to bus events.
	-- Handlers are closures; self is captured for state access.
	ctx.bus:on("entity_spawned", function(data)
		self._last_spawned = data.entity
	end)

	-- 4. Service registration — expose a query accessor for other plugins.
	-- Services are stateless query providers; no ECS mutations or bus emissions.
	ctx.services:register("canonical_query", {
		get_movement_query = function()
			return self._movement_query
		end,
	})
end

--- System update — called each tick by the game loop.
--- Processes all entities with Position + Velocity and integrates motion.
--- In dual-world mode, only server-tagged entities are processed.
--- @param dt number Delta time in seconds
function CanonicalPlugin:update(dt)
	for chunk, _entities, count in evolved.execute(self._movement_query) do
		local positions, velocities = chunk:components(Position, Velocity)
		for i = 1, count do
			positions[i].x = positions[i].x + velocities[i].dx * dt
			positions[i].y = positions[i].y + velocities[i].dy * dt
		end
	end
end

--- Shutdown stub — contract established for future use.
--- Called by the registry in reverse boot order during teardown.
--- @param _ctx table Context (unused — no cleanup needed for this example)
function CanonicalPlugin:shutdown(_ctx)
	-- No-op: cleanup will be implemented when save/load or resource management requires it.
end

return CanonicalPlugin
