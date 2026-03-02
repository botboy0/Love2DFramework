--- AssetLoader: Lily wrapper for async asset loading.
---
--- Wraps the Lily library with manual update mode. All Lily callbacks emit bus
--- events only — no direct ECS mutations (ASST-04). The caller must invoke
--- loader:update() each frame to trigger completed callbacks synchronously.
---
--- Usage:
---   local AssetLoader = require("src.plugins.assets.asset_loader")
---   local loader = AssetLoader.new({ bus = bus })
---   loader:load_manifest(load_requests)
---   -- each frame:
---   loader:update()
---   bus:flush()
---
--- Dependency injection via opts:
---   opts.lily        -- Lily library (defaults to require("lib.lily"))
---   opts.bus         -- event bus (required)
---   opts.error_mode  -- "strict" (default) or "tolerant"
---   opts.log         -- logging fn (defaults to print)
---
--- Pure-Lua injectable interface — no Love2D runtime required in tests.

local AssetLoader = {}
AssetLoader.__index = AssetLoader

--- Create a new AssetLoader.
--- @param opts table  { lily, bus, error_mode, log }
--- @return AssetLoader
function AssetLoader.new(opts)
	opts = opts or {}
	local lily = opts.lily or require("lib.lily")
	local bus = opts.bus
	local error_mode = opts.error_mode or "strict"
	local log = opts.log or print

	assert(bus, "AssetLoader.new: opts.bus is required")

	-- Set Lily to manual update mode — callbacks fire only when update() is called.
	lily.setUpdateMode("manual")

	return setmetatable({
		_lily = lily,
		_bus = bus,
		_error_mode = error_mode,
		_log = log,
		_loaded = {},
		_manifest_complete = true, -- true when no active manifest batch
		_pending_singles = 0, -- count of in-flight load_single batches
	}, AssetLoader)
end

--- Start an async batch load for all items in load_requests.
--- Registers Lily callbacks that emit bus events on completion.
--- @param load_requests table  Array of { key, path, type, group, extra }
function AssetLoader:load_manifest(load_requests)
	if not load_requests or #load_requests == 0 then
		return
	end

	local items = {}
	local pending_keys = {} -- index -> key for onLoaded callback

	for i, req in ipairs(load_requests) do
		pending_keys[i] = req.key
		if req.type == "image" then
			items[i] = { self._lily.newImage, req.path }
		elseif req.type == "font" then
			local size = (req.extra and req.extra.size) or 12
			items[i] = { self._lily.newFont, req.path, size }
		elseif req.type == "sound" then
			local mode = (req.extra and req.extra.mode) or "static"
			items[i] = { self._lily.newSource, req.path, mode }
		end
	end

	self._manifest_complete = false
	local handle = self._lily.loadMulti(items)

	-- Per-item callback: emit "asset:loaded" event.
	handle:onLoaded(function(_self, index, value)
		local key = pending_keys[index]
		local req = load_requests[index]
		self._loaded[key] = value
		self._bus:emit("asset:loaded", { key = key, type = req.type, path = req.path })
	end)

	-- Batch complete callback: emit "asset:batch_complete" event.
	handle:onComplete(function(_self, _values)
		local all_keys = {}
		for _, key in ipairs(pending_keys) do
			table.insert(all_keys, key)
		end
		self._bus:emit("asset:batch_complete", { keys = all_keys })
		self._manifest_complete = true
	end)

	-- Error callback: strict raises, tolerant logs.
	handle:onError(function(_self, msg, _trace)
		if self._error_mode == "strict" then
			error("[AssetLoader] Lily error: " .. tostring(msg), 0)
		else
			self._log("[AssetLoader] Warning: Lily error — " .. tostring(msg))
		end
	end)
end

--- Load a single asset asynchronously (on-demand).
--- Emits "asset:loaded" when complete.
--- @param key        string  Asset key
--- @param path       string  File path
--- @param asset_type string  "image", "font", or "sound"
--- @param extra      table|nil  Extra params ({ size } for font, { mode } for sound)
function AssetLoader:load_single(key, path, asset_type, extra)
	local item
	if asset_type == "image" then
		item = { self._lily.newImage, path }
	elseif asset_type == "font" then
		local size = (extra and extra.size) or 12
		item = { self._lily.newFont, path, size }
	elseif asset_type == "sound" then
		local mode = (extra and extra.mode) or "static"
		item = { self._lily.newSource, path, mode }
	end

	self._pending_singles = self._pending_singles + 1
	local handle = self._lily.loadMulti({ item })

	handle:onLoaded(function(_self, _index, value)
		self._loaded[key] = value
		self._bus:emit("asset:loaded", { key = key, type = asset_type, path = path })
	end)

	handle:onComplete(function(_self, _values)
		self._pending_singles = self._pending_singles - 1
	end)

	handle:onError(function(_self, msg, _trace)
		self._pending_singles = self._pending_singles - 1
		if self._error_mode == "strict" then
			error("[AssetLoader] Lily error: " .. tostring(msg), 0)
		else
			self._log("[AssetLoader] Warning: Lily error — " .. tostring(msg))
		end
	end)
end

--- Trigger Lily's pending callbacks synchronously.
--- Call this once per frame (before bus:flush()).
function AssetLoader:update()
	self._lily.update()
end

--- Return true when all pending loads (manifest + singles) are complete.
--- @return boolean
function AssetLoader:is_complete()
	return self._manifest_complete and self._pending_singles == 0
end

--- Return the table of loaded assets, keyed by asset key.
--- @return table  key -> loaded Love2D object
function AssetLoader:get_loaded()
	return self._loaded
end

--- Shut down Lily and release its worker threads.
--- Call this on game exit or when the plugin is unloaded.
function AssetLoader:shutdown()
	self._lily.quit()
end

return AssetLoader
