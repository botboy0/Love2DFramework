--- AtlasBuilder: RTA wrapper for texture atlas packing.
---
--- Wraps the Runtime-TextureAtlas (TA) library. Packs image groups into atlases
--- capped at max_size x max_size (default 4096x4096). Groups whose total pixel
--- area exceeds the budget are automatically split into numbered sub-groups with
--- a warning logged.
---
--- Usage:
---   local AtlasBuilder = require("src.plugins.assets.atlas_builder")
---   local builder = AtlasBuilder.new({ ... })
---   local atlases = builder:build(groups, loaded_images)
---   -- atlases["sprites"] = { canvas = ..., wrappers = { key -> DrawableWrapper } }
---
--- Dependency injection via opts:
---   opts.ta               -- TA library (defaults to require("lib.TA"))
---   opts.love_graphics    -- love.graphics table (defaults to love.graphics at call time)
---   opts.drawable_wrapper -- DrawableWrapper module (defaults to require(...))
---   opts.log              -- logging fn (defaults to print)
---   opts.max_size         -- maximum atlas dimension in pixels (default 4096)
---
--- Pure-Lua injectable interface — no Love2D runtime required in tests.

local AtlasBuilder = {}
AtlasBuilder.__index = AtlasBuilder

--- Create a new AtlasBuilder.
--- @param opts table  { ta, love_graphics, drawable_wrapper, log, max_size }
--- @return AtlasBuilder
function AtlasBuilder.new(opts)
	opts = opts or {}
	local ta = opts.ta or require("lib.TA")
	local love_graphics = opts.love_graphics
	local drawable_wrapper = opts.drawable_wrapper or require("src.plugins.assets.drawable_wrapper")
	local log = opts.log or print
	local max_size = opts.max_size or 4096

	-- Defer love.graphics lookup to call time when not injected (safe in tests)
	if not love_graphics then
		love_graphics = love and love.graphics
	end

	return setmetatable({
		_ta = ta,
		_love_graphics = love_graphics,
		_drawable_wrapper = drawable_wrapper,
		_log = log,
		_max_size = max_size,
		_atlases = {},
	}, AtlasBuilder)
end

--- Pack groups of images into atlases.
--- Groups exceeding the pixel area budget are auto-split into numbered sub-groups.
---
--- @param groups        table  group_name -> { key1, key2, ... }
--- @param loaded_images table  key -> Love2D image object (with getDimensions())
--- @return table  group_name -> { canvas, wrappers = { key -> DrawableWrapper } }
function AtlasBuilder:build(groups, loaded_images)
	local budget = self._max_size * self._max_size

	for group_name, keys in pairs(groups) do
		-- Calculate total pixel area for this group
		local total_area = 0
		for _, key in ipairs(keys) do
			local img = loaded_images[key]
			if img then
				local w, h = img:getDimensions()
				total_area = total_area + (w * h)
			end
		end

		if total_area > budget then
			-- Auto-split: partition keys into sub-groups that fit within budget
			local sub_groups = self:_split_group(keys, loaded_images, budget)
			local n = #sub_groups

			self._log(
				string.format(
					"[AtlasBuilder] Group '%s' split into %d atlases (exceeded %dx%d). "
						.. "Consider splitting into smaller groups.",
					group_name,
					n,
					self._max_size,
					self._max_size
				)
			)

			for i, sub_keys in ipairs(sub_groups) do
				local sub_name = group_name .. "_" .. i
				self:_pack_atlas(sub_name, sub_keys, loaded_images)
			end
		else
			-- Normal path: pack entire group into one atlas
			self:_pack_atlas(group_name, keys, loaded_images)
		end
	end

	return self._atlases
end

--- Internal: split keys into sub-groups that each fit within the pixel budget.
--- Uses a greedy descending-area bin-fill algorithm.
--- @param keys          table   array of key strings
--- @param loaded_images table   key -> image
--- @param budget        number  max pixel area per sub-group
--- @return table  array of sub-group key arrays
function AtlasBuilder:_split_group(keys, loaded_images, budget)
	-- Sort keys by pixel area descending (largest first)
	local sorted = {}
	for _, key in ipairs(keys) do
		local img = loaded_images[key]
		local area = 0
		if img then
			local w, h = img:getDimensions()
			area = w * h
		end
		table.insert(sorted, { key = key, area = area })
	end
	table.sort(sorted, function(a, b)
		return a.area > b.area
	end)

	-- Greedy fill: place each image into the first sub-group that has room
	local sub_groups = {}
	local sub_group_areas = {}

	for _, item in ipairs(sorted) do
		local placed = false
		for i, sg in ipairs(sub_groups) do
			if sub_group_areas[i] + item.area <= budget then
				table.insert(sg, item.key)
				sub_group_areas[i] = sub_group_areas[i] + item.area
				placed = true
				break
			end
		end
		if not placed then
			-- Start a new sub-group
			table.insert(sub_groups, { item.key })
			table.insert(sub_group_areas, item.area)
		end
	end

	return sub_groups
end

--- Internal: create one atlas for a set of keys and store the result.
--- @param name          string  atlas name (stored in self._atlases)
--- @param keys          table   array of key strings
--- @param loaded_images table   key -> image
function AtlasBuilder:_pack_atlas(name, keys, loaded_images)
	-- Create atlas with standard padding/extrude/spacing
	local atlas = self._ta.newDynamicSize(1, 0, 1)
	atlas:setMaxSize(self._max_size, self._max_size)

	-- Add all images to the atlas
	for _, key in ipairs(keys) do
		local img = loaded_images[key]
		if img then
			atlas:add(img, key)
		end
	end

	-- Bake (pack) the atlas
	atlas:bake("area")

	-- Retrieve the canvas (try public method first, fall back to _canvas field)
	local canvas
	if atlas.getCanvas then
		canvas = atlas:getCanvas()
	else
		canvas = atlas._canvas
	end

	-- Create DrawableWrappers for each key
	local wrappers = {}
	for _, key in ipairs(keys) do
		if loaded_images[key] then
			local x, y, w, h = atlas:getViewport(key)
			local sw, sh = canvas:getDimensions()
			local quad = self._love_graphics.newQuad(x, y, w, h, sw, sh)
			wrappers[key] = self._drawable_wrapper.from_atlas(canvas, quad)
		end
	end

	self._atlases[name] = {
		canvas = canvas,
		wrappers = wrappers,
	}
end

--- Return the atlas info for a specific group name.
--- @param group_name string
--- @return table|nil  { canvas, wrappers } or nil if not built
function AtlasBuilder:get_atlas(group_name)
	return self._atlases[group_name]
end

--- Return the full atlases table.
--- @return table  group_name -> { canvas, wrappers }
function AtlasBuilder:get_all_atlases()
	return self._atlases
end

return AtlasBuilder
