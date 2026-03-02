--- Plugin test harness
--- Creates an isolated context (worlds, bus, services) for testing plugins.
--- Uses real infrastructure (Bus, Worlds, Context) — not stubs.
---
--- Plugins declare dependencies explicitly; undeclared dependencies are violations.
--- Dependencies are passed as a name->service table in opts.deps.
---
--- Usage:
---   local harness = require("tests.helpers.plugin_harness")
---   local ctx = harness.create_context({ deps = { inventory = InventoryServiceStub } })
---   MyPlugin:init(ctx)
---   harness.teardown(ctx)

local Bus = require("src.core.bus")
local Context = require("src.core.context")
local Worlds = require("src.core.worlds")
local evolved = require("lib.evolved")

local plugin_harness = {}

--- Create a dependency-enforced proxy around a real Services object.
--- Intercepts :get() calls and checks that the requested service name is in the
--- allowed_deps list. Behaviour on violation is controlled by error_mode:
---   "strict"   (default) — error() with a descriptive message
---   "tolerant"            — prints a warning and falls through to the real service
--- All other method calls (register, etc.) are delegated transparently.
--- @param real_services table  The real Services instance to wrap.
--- @param allowed_deps table   Array of allowed service names (e.g. {"inventory"}).
--- @param error_mode string    "strict" | "tolerant"
--- @return table proxy
local function make_dep_enforced_services(real_services, allowed_deps, error_mode)
	-- Build a set for O(1) lookup
	local allowed = {}
	for _, name in ipairs(allowed_deps) do
		allowed[name] = true
	end

	local proxy = {}
	setmetatable(proxy, {
		__index = function(_t, key)
			if key == "get" then
				-- Return a wrapped :get() that enforces allowed_deps
				return function(_self, name)
					if not allowed[name] then
						local msg = string.format(
							"Plugin accessed undeclared service '%s' -- add it to deps",
							name
						)
						if error_mode == "tolerant" then
							print(string.format("[Harness] %s", msg))
							return real_services:get(name)
						else
							error(msg, 2)
						end
					end
					return real_services:get(name)
				end
			end
			-- Delegate all other keys to the real services object.
			-- If the value is a function, wrap it as a method call on real_services.
			local v = real_services[key]
			if type(v) == "function" then
				return function(_self, ...)
					return v(real_services, ...)
				end
			end
			return v
		end,
	})
	return proxy
end

--- Create an isolated test context for a plugin using real infrastructure.
--- @param opts table Optional overrides:
---   { deps = { name = service }, config = {}, allowed_deps = {"name"}, error_mode = "strict"|"tolerant" }
--- @return table ctx The plugin context: { worlds, bus, config, services }
function plugin_harness.create_context(opts)
	opts = opts or {}

	local bus = Bus.new()
	local worlds = Worlds.create({ dual = true })
	local ctx = Context.new({
		worlds = worlds,
		bus = bus,
		config = opts.config or {},
	})

	-- Pre-register declared dependency services (name -> service provider table).
	-- Accepts both:
	--   { "dep_name" } (legacy array — registers stub)
	--   { dep_name = service }  (current — registers real service)
	if opts.deps then
		-- Detect format: if first value is a string, treat as legacy array of names
		local is_array = type(opts.deps[1]) == "string"
		if is_array then
			for _, dep_name in ipairs(opts.deps) do
				ctx.services:register(dep_name, { _stub = true })
			end
		else
			-- name -> service table
			for name, service in pairs(opts.deps) do
				ctx.services:register(name, service)
			end
		end
	end

	-- Install dependency enforcement proxy if allowed_deps is specified.
	-- error_mode defaults to "strict" — use "tolerant" to warn instead of error.
	if opts.allowed_deps then
		local error_mode = opts.error_mode or "strict"
		ctx.services = make_dep_enforced_services(ctx.services, opts.allowed_deps, error_mode)
	end

	return ctx
end

--- Tear down a test context — destroys any spawned ECS entities and clears bus handlers.
--- @param _ctx table The context to tear down (unused; present for API symmetry)
--- @param spawned table|nil Optional list of evolved.entity to destroy (from worlds:spawn_*)
function plugin_harness.teardown(_ctx, spawned)
	-- Destroy any tracked ECS entities (evolved.lua singleton cleanup)
	if spawned and #spawned > 0 then
		evolved.defer()
		for _, e in ipairs(spawned) do
			if evolved.alive(e) then
				evolved.destroy(e)
			end
		end
		evolved.commit()
	end
	-- Bus is a plain table; no global cleanup needed.
	-- Context and worlds are local — they will be GC'd.
end

return plugin_harness
