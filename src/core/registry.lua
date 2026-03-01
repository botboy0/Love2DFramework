--- Plugin registry with topological dependency sort and fail-fast boot.
---
--- Plugins are registered with explicit dependency lists. boot() performs
--- a topological sort (Kahn's BFS algorithm) and calls plugin:init(ctx) in
--- dependency order. Missing or cyclic dependencies cause a boot-time error
--- before any plugin:init runs.
---
--- Usage:
---   local Registry = require("src.core.registry")
---   local registry = Registry.new()
---   registry:register("inventory", InventoryPlugin)
---   registry:register("crafting", CraftingPlugin, { deps = { "inventory" } })
---   registry:boot(ctx)
---   -- later:
---   registry:shutdown(ctx)

local Registry = {}
Registry.__index = Registry

--- Create a new Registry instance.
--- @return table registry
function Registry.new()
	return setmetatable({
		_plugins = {}, -- array of { name, module, deps }
		_boot_order = {}, -- populated after boot(); used for shutdown
		_booted = false,
	}, Registry)
end

--- Register a plugin with the registry.
--- @param name string  unique plugin name
--- @param plugin_module table  plugin object with :init(ctx) method
--- @param opts table|nil  optional opts; opts.deps = { "dep_name", ... }
function Registry:register(name, plugin_module, opts)
	opts = opts or {}
	table.insert(self._plugins, {
		name = name,
		module = plugin_module,
		deps = opts.deps or {},
	})
end

--- Validate all declared dependencies exist.
--- Errors before any init runs if a dependency is missing.
--- @param entries table  array of { name, module, deps }
local function validate_deps(entries)
	-- Build a set of registered names for O(1) lookup
	local registered = {}
	for _, entry in ipairs(entries) do
		registered[entry.name] = true
	end

	for _, entry in ipairs(entries) do
		for _, dep in ipairs(entry.deps) do
			if not registered[dep] then
				error(string.format("Plugin '%s' depends on '%s' which is not registered", entry.name, dep))
			end
		end
	end
end

--- Topological sort using Kahn's BFS algorithm.
--- Returns sorted array of entry tables, or errors on cycle.
--- @param entries table  array of { name, module, deps }
--- @return table  sorted array of entries
local function topological_sort(entries)
	-- Build adjacency list and in-degree count
	-- edge: dep -> entry (dep must come before entry)
	local in_degree = {}
	local adjacency = {} -- name -> array of names that depend on it

	for _, entry in ipairs(entries) do
		if in_degree[entry.name] == nil then
			in_degree[entry.name] = 0
		end
		if not adjacency[entry.name] then
			adjacency[entry.name] = {}
		end
	end

	for _, entry in ipairs(entries) do
		for _, dep in ipairs(entry.deps) do
			-- dep -> entry.name edge
			table.insert(adjacency[dep], entry.name)
			in_degree[entry.name] = in_degree[entry.name] + 1
		end
	end

	-- Build lookup: name -> entry
	local by_name = {}
	for _, entry in ipairs(entries) do
		by_name[entry.name] = entry
	end

	-- Collect all nodes with in-degree 0 (no unresolved deps)
	-- Preserve original registration order within same degree for stability
	local queue = {}
	for _, entry in ipairs(entries) do
		if in_degree[entry.name] == 0 then
			table.insert(queue, entry.name)
		end
	end

	local sorted = {}
	local head = 1

	while head <= #queue do
		local name = queue[head]
		head = head + 1
		table.insert(sorted, by_name[name])

		-- Reduce in-degree of all dependents; enqueue those that reach 0
		for _, dependent in ipairs(adjacency[name]) do
			in_degree[dependent] = in_degree[dependent] - 1
			if in_degree[dependent] == 0 then
				table.insert(queue, dependent)
			end
		end
	end

	-- If not all nodes were processed, there is a cycle
	if #sorted ~= #entries then
		-- Collect the names still in the cycle (in_degree > 0)
		local cycle_nodes = {}
		for name, deg in pairs(in_degree) do
			if deg > 0 then
				table.insert(cycle_nodes, name)
			end
		end
		table.sort(cycle_nodes)
		error(string.format("Cyclic dependency detected among plugins: %s", table.concat(cycle_nodes, " -> ")))
	end

	return sorted
end

--- Boot all registered plugins in topological dependency order.
--- Errors with a descriptive message if any dependency is missing or cyclic.
--- No plugin:init is called if validation fails.
--- @param ctx table  context object passed to each plugin:init
function Registry:boot(ctx)
	-- Step 1: Fail-fast on missing deps (before any init runs)
	validate_deps(self._plugins)

	-- Step 2: Topological sort (errors on cycle before any init runs)
	local sorted = topological_sort(self._plugins)

	-- Step 3: Call init in sorted order
	self._boot_order = sorted
	for _, entry in ipairs(sorted) do
		entry.module:init(ctx)
	end

	self._booted = true
end

--- Shut down all booted plugins in reverse boot order.
--- Calls plugin:shutdown(ctx) for each plugin that defines it.
--- Safe to call even if some plugins lack a shutdown method.
--- @param ctx table  context object passed to each plugin:shutdown
function Registry:shutdown(ctx)
	-- Reverse boot order
	for i = #self._boot_order, 1, -1 do
		local entry = self._boot_order[i]
		if entry.module.shutdown then
			entry.module:shutdown(ctx)
		end
	end
end

return Registry
