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

--- Create an isolated test context for a plugin using real infrastructure.
--- @param opts table Optional overrides: { deps = { name = service }, config = {} }
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
