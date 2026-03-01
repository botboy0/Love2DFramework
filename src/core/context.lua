--- Context object factory.
---
--- Every plugin receives a `ctx` table at init time. Context bundles the dual
--- ECS worlds, event bus, configuration, and a service registry into a single
--- interface. This is the standard injection point for all plugin dependencies.
---
--- Usage:
---   local Context = require("src.core.context")
---   local ctx = Context.new({ worlds = worlds, bus = bus, config = {} })
---   ctx.services:register("inventory", InventoryService)
---   local inv = ctx.services:get("inventory")

local Context = {}
Context.__index = Context

--- Services sub-object: fail-fast named service registry.
--- Services are stateless query providers — no ECS mutations, no event emission.
local Services = {}
Services.__index = Services

--- Create a new empty Services registry.
--- @return table services
function Services.new()
	return setmetatable({ _registry = {} }, Services)
end

--- Register a named service. Errors if the name is already registered.
--- @param name string The service name (snake_case).
--- @param provider any The service object.
function Services:register(name, provider)
	if self._registry[name] ~= nil then
		error(string.format("Service '%s' is already registered — duplicate registration is not allowed", name))
	end
	self._registry[name] = provider
end

--- Retrieve a named service. Errors with a descriptive message if not found.
--- @param name string The service name to look up.
--- @return any provider The registered service object.
function Services:get(name)
	local provider = self._registry[name]
	if provider == nil then
		error(string.format("Service '%s' not found — did the owning plugin forget to register it?", name))
	end
	return provider
end

--- Create a new context object.
--- @param opts table Optional fields: { worlds, bus, config }
--- @return table ctx The context object.
function Context.new(opts)
	opts = opts or {}
	return setmetatable({
		worlds = opts.worlds,
		bus = opts.bus,
		config = opts.config or {},
		services = Services.new(),
	}, Context)
end

return Context
