--- Plugin test harness
--- Creates an isolated context (world, bus, registry) for testing plugins.
--- Plugins declare dependencies explicitly; undeclared dependencies are violations.
local plugin_harness = {}

--- Create an isolated test context for a plugin.
--- @param opts table Optional overrides: { deps = {}, config = {} }
--- @return table ctx The plugin context: { world, bus, config, services }
function plugin_harness.create_context(opts)
	opts = opts or {}

	-- Stub world (replaced by evolved.lua ECS world in Phase 2)
	local world = {
		_entities = {},
		_components = {},
		addEntity = function(self, entity)
			table.insert(self._entities, entity)
			return entity
		end,
		removeEntity = function(self, entity)
			for i, e in ipairs(self._entities) do
				if e == entity then
					table.remove(self._entities, i)
					return
				end
			end
		end,
	}

	-- Stub event bus (replaced by real deferred-dispatch bus in Phase 2)
	local bus = {
		_handlers = {},
		on = function(self, event, handler)
			self._handlers[event] = self._handlers[event] or {}
			table.insert(self._handlers[event], handler)
		end,
		emit = function(self, event, ...)
			local handlers = self._handlers[event] or {}
			for _, handler in ipairs(handlers) do
				handler(...)
			end
		end,
	}

	-- Stub registry
	local registry = {
		_plugins = {},
		register = function(self, name, plugin)
			self._plugins[name] = plugin
		end,
		get = function(self, name)
			return self._plugins[name]
		end,
	}

	local ctx = {
		world = world,
		bus = bus,
		config = opts.config or {},
		services = {},
		registry = registry,
	}

	-- Load declared dependencies only
	if opts.deps then
		for _, dep_name in ipairs(opts.deps) do
			-- In Phase 2 this will actually load the dependency plugin
			ctx.services[dep_name] = { _stub = true }
		end
	end

	return ctx
end

--- Tear down a test context (cleanup).
--- @param ctx table The context to tear down
function plugin_harness.teardown(ctx)
	if ctx.world then
		ctx.world._entities = {}
		ctx.world._components = {}
	end
	if ctx.bus then
		ctx.bus._handlers = {}
	end
	if ctx.registry then
		ctx.registry._plugins = {}
	end
end

return plugin_harness
