--- Canonical Plugin Example
--- This is the reference implementation for all game plugins.
--- See CLAUDE.md for architectural rules.
---
--- PLACEHOLDER: Will be fully implemented in Phase 2 when
--- the event bus, plugin registry, and ECS worlds are available.

local CanonicalPlugin = {}

--- Standard plugin init function.
--- @param ctx table { world, bus, config, services }
function CanonicalPlugin:init(ctx)
	self.world = ctx.world
	self.bus = ctx.bus

	-- Phase 2: Register components
	-- Phase 2: Register systems
	-- Phase 2: Register event handlers
end

return CanonicalPlugin
