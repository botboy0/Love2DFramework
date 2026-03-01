--- Canonical Plugin Example
--- Reference implementation for all game plugins.
--- Demonstrates: init with ctx, component usage, system query, event handling,
--- service registration, and shutdown stub.
---
--- All future plugins follow this pattern. See CLAUDE.md for architectural rules.
---
--- NOTE: examples/ is NOT loaded at runtime — this is a reference only.

local Components = require("src.core.components")
local evolved = require("lib.evolved")

local CanonicalPlugin = {}

--- Plugin metadata
CanonicalPlugin.name = "canonical"
CanonicalPlugin.deps = {} -- no external dependencies for the example

--- Initialize the plugin.
--- Called by the plugin registry during boot in dependency order.
--- @param ctx table { worlds, bus, config, services }
function CanonicalPlugin:init(ctx)
	self.bus = ctx.bus
	self.worlds = ctx.worlds

	-- 1. Component usage — shared fragments from src/core/components.lua.
	-- Components are defined centrally, not per-plugin. Plugins consume them.
	-- Example: Components.Position, Components.Velocity, Components.Health

	-- 2. System query — build a query for server entities with Position + Velocity.
	-- ServerTag scopes this query to the server world only.
	self._movement_query =
		evolved.builder():include(Components.Position, Components.Velocity):include(ctx.worlds.server.tag):build()

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
--- Processes all server entities with Position + Velocity and integrates motion.
--- @param dt number Delta time in seconds
function CanonicalPlugin:update(dt)
	for chunk, _entities, count in evolved.execute(self._movement_query) do
		local positions, velocities = chunk:components(Components.Position, Components.Velocity)
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
