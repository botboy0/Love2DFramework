--- Plugin registry with topological dependency sort, fail-fast boot,
--- error_mode support, and optional side enforcement for dual-world setups.
---
--- Plugins are registered with explicit dependency lists. boot() performs
--- a topological sort (Kahn's BFS algorithm) and calls plugin:init(ctx) in
--- dependency order. Missing or cyclic dependencies cause a boot-time error
--- before any plugin:init runs.
---
--- Error modes:
---   "strict" (default) — plugin init errors propagate from boot(); boot aborts.
---   "tolerant" — plugin init errors are logged; boot continues with remaining plugins.
---     Failed plugins are excluded from the shutdown order.
---
--- Side enforcement (dual-world only):
---   When a plugin has side = "server" or side = "client" and the worlds handle
---   has both .server and .client fields, cross-side dependencies are rejected.
---   In single-world mode, side declarations are stored but not enforced.
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

--- Create a new Registry instance.
--- @param opts table|nil  optional: { config = { error_mode = "strict"|"tolerant", error_modes = {...} }, log = fn }
--- @return table registry
function Registry.new(opts)
	opts = opts or {}
	local config = opts.config or {}
	return setmetatable({
		_plugins = {}, -- array of { name, module, deps, side }
		_boot_order = {}, -- populated after boot(); used for shutdown (only successful plugins)
		_booted = false,
		_error_mode = resolve_error_mode(config, "registry", "strict"),
		_log = opts.log or print,
	}, Registry)
end

--- Register a plugin with the registry.
--- @param name string  unique plugin name
--- @param plugin_module table  plugin object with :init(ctx) method
--- @param opts table|nil  optional opts; opts.deps = { "dep_name", ... }; opts.side = "server"|"client"|nil
function Registry:register(name, plugin_module, opts)
	opts = opts or {}
	table.insert(self._plugins, {
		name = name,
		module = plugin_module,
		deps = opts.deps or {},
		side = opts.side, -- nil, "server", or "client"
	})
end

--- Check whether worlds represents a dual-world setup.
--- A dual-world has both .server and .client sub-handles.
--- @param worlds table|nil
--- @return boolean
local function is_dual_world(worlds)
	return worlds ~= nil and worlds.server ~= nil and worlds.client ~= nil
end

--- Validate all declared dependencies exist.
--- Optionally enforces side constraints when dual_mode is true.
--- Errors before any init runs if a dependency is missing or side-incompatible.
--- @param entries table  array of { name, module, deps, side }
--- @param dual_mode boolean  whether to enforce side constraints
local function validate_deps(entries, dual_mode)
	-- Build a set of registered names and their sides for O(1) lookup
	local registered = {}
	local sides = {}
	for _, entry in ipairs(entries) do
		registered[entry.name] = true
		sides[entry.name] = entry.side
	end

	for _, entry in ipairs(entries) do
		for _, dep in ipairs(entry.deps) do
			if not registered[dep] then
				error(string.format("Plugin '%s' depends on '%s' which is not registered", entry.name, dep))
			end

			-- Side enforcement: only in dual-world mode, only when both sides are set
			if dual_mode and entry.side ~= nil and sides[dep] ~= nil then
				if entry.side ~= sides[dep] then
					error(
						string.format(
							"Side violation: '%s' (%s) depends on '%s' (%s) — cross-side dependencies are not allowed in dual-world mode",
							entry.name,
							entry.side,
							dep,
							sides[dep]
						)
					)
				end
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
--- In strict mode (default): errors from plugin:init propagate and abort boot.
--- In tolerant mode: errors from plugin:init are logged; boot continues.
--- @param ctx table  context object passed to each plugin:init
function Registry:boot(ctx)
	-- Determine if worlds is dual-mode for side enforcement
	local dual_mode = is_dual_world(ctx and ctx.worlds)

	-- Step 1: Fail-fast on missing deps and side violations (before any init runs)
	validate_deps(self._plugins, dual_mode)

	-- Step 2: Topological sort (errors on cycle before any init runs)
	local sorted = topological_sort(self._plugins)

	-- Step 3: Call init in sorted order
	-- Only successfully initialized plugins enter _boot_order (for shutdown)
	self._boot_order = {}

	if self._error_mode == "tolerant" then
		for _, entry in ipairs(sorted) do
			local ok, err = pcall(entry.module.init, entry.module, ctx)
			if ok then
				table.insert(self._boot_order, entry)
			else
				self._log(
					string.format("[Registry] Plugin '%s' init failed (tolerant mode): %s", entry.name, tostring(err))
				)
			end
		end
	else
		-- Strict mode: let errors propagate
		for _, entry in ipairs(sorted) do
			entry.module:init(ctx)
			table.insert(self._boot_order, entry)
		end
	end

	self._booted = true
end

--- Call update(dt) on all booted plugins in boot order.
--- Plugins without an update method are silently skipped.
--- In strict mode (default): errors from plugin:update propagate.
--- In tolerant mode: errors from plugin:update are logged; remaining plugins still update.
--- Safe to call before boot() — _boot_order is empty so it is a no-op.
--- @param dt number  delta-time passed through to each plugin:update
function Registry:update_all(dt)
	if self._error_mode == "tolerant" then
		for _, entry in ipairs(self._boot_order) do
			if entry.module.update then
				local ok, err = pcall(entry.module.update, entry.module, dt)
				if not ok then
					self._log(
						string.format(
							"[Registry] Plugin '%s' update failed (tolerant mode): %s",
							entry.name,
							tostring(err)
						)
					)
				end
			end
		end
	else
		-- Strict mode: let errors propagate
		for _, entry in ipairs(self._boot_order) do
			if entry.module.update then
				entry.module:update(dt)
			end
		end
	end
end

--- Call draw() on all booted plugins in boot order.
--- Plugins without a draw method are silently skipped.
--- In strict mode (default): errors from plugin:draw propagate.
--- In tolerant mode: errors from plugin:draw are logged; remaining plugins still draw.
--- Safe to call before boot() — _boot_order is empty so it is a no-op.
function Registry:draw_all()
	if self._error_mode == "tolerant" then
		for _, entry in ipairs(self._boot_order) do
			if entry.module.draw then
				local ok, err = pcall(entry.module.draw, entry.module)
				if not ok then
					self._log(
						string.format(
							"[Registry] Plugin '%s' draw failed (tolerant mode): %s",
							entry.name,
							tostring(err)
						)
					)
				end
			end
		end
	else
		-- Strict mode: let errors propagate
		for _, entry in ipairs(self._boot_order) do
			if entry.module.draw then
				entry.module:draw()
			end
		end
	end
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
