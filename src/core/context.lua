--- Context object factory.
---
--- Every plugin receives a `ctx` table at init time. Context bundles the dual
--- ECS worlds, event bus, configuration, transport, and a service registry into
--- a single interface. This is the standard injection point for all plugin
--- dependencies.
---
--- Transport wiring:
---   opts.transport = nil | false  → ctx.transport is a NullTransport (no-op stub)
---   opts.transport = true         → Context creates a real Transport using opts.transport_channels
---   opts.transport = <instance>   → ctx.transport uses the provided instance as-is
---
--- Auto-bridge:
---   After transport is wired, bus:emit() is wrapped so that any event marked
---   networkable on the transport is also queued on the transport. This is
---   transparent to callers — original emit semantics are preserved.
---
--- Usage:
---   local Context = require("src.core.context")
---   local ctx = Context.new({ worlds = worlds, bus = bus, config = {} })
---   ctx.services:register("inventory", InventoryService)
---   local inv = ctx.services:get("inventory")

local Transport = require("src.core.transport")

local Context = {}
Context.__index = Context

--- Resolve error_mode from a config table.
--- Checks module-specific override first, then global, then fallback.
--- @param config table|nil
--- @param module_name string
--- @param fallback string
--- @return string
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

--- Resolve the transport instance from opts.
--- Returns a Transport instance (real or null) based on opts.transport.
--- @param opts table
--- @return table transport
local function resolve_transport(opts)
	local transport_opt = opts.transport

	if transport_opt == nil or transport_opt == false then
		-- No transport requested — use null stub
		return Transport.Null.new()
	end

	if transport_opt == true then
		-- Framework should create a real Transport; require channels to be provided
		local channels = opts.transport_channels
		if not channels or not channels.outbound or not channels.inbound then
			error(
				"Context.new: transport = true requires opts.transport_channels = { outbound = channel, inbound = channel }"
			)
		end
		return Transport.new({
			outbound_channel = channels.outbound,
			inbound_channel = channels.inbound,
		})
	end

	-- Duck-type check: assume it is a Transport instance if it has mark_networkable
	if type(transport_opt) == "table" and transport_opt.mark_networkable then
		return transport_opt
	end

	error("Context.new: opts.transport must be nil, false, true, or a Transport instance")
end

--- Install the auto-bridge: wraps bus:emit() so that networkable events are
--- also queued on the transport. Original emit semantics are fully preserved.
--- @param bus table  the bus instance to wrap
--- @param transport table  the transport to forward networkable events to
local function install_auto_bridge(bus, transport)
	local original_emit = bus.emit
	bus.emit = function(self_bus, event, data)
		original_emit(self_bus, event, data)
		if transport:is_networkable(event) then
			transport:queue(event, data)
		end
	end
end

--- Create a new context object.
--- @param opts table Optional fields: { worlds, bus, config, transport, transport_channels }
--- @return table ctx The context object.
function Context.new(opts)
	opts = opts or {}
	local config = opts.config or {}

	-- Resolve transport (null or real)
	local transport = resolve_transport(opts)

	-- Wire auto-bridge on the bus (if a bus is provided)
	local bus = opts.bus
	if bus then
		install_auto_bridge(bus, transport)
	end

	-- Resolve Services error_mode from config (default: strict)
	local _services_error_mode = resolve_error_mode(config, "services", "strict")

	return setmetatable({
		worlds = opts.worlds,
		bus = bus,
		config = config,
		transport = transport,
		services = Services.new(),
		_services_error_mode = _services_error_mode,
	}, Context)
end

return Context
