--- Touch region tracker for the input plugin.
--- Parses touch bindings from the input config and provides per-frame pressed/down/released state.
---
--- Regions are rectangular and support two unit types:
---   "px"  -- absolute pixel coordinates
---   "pct" -- percentage of screen dimensions (0.0–1.0)
---
--- Hit test: x >= rx and x < rx + rw and y >= ry and y < ry + rh
---
--- Usage:
---   local TouchRegions = require("src.plugins.input.touch_regions")
---   local tr = TouchRegions.new(ctx.config.input, { screen_w = 800, screen_h = 600 })
---   tr:on_touch_pressed(id, x, y)
---   tr:update()
---   tr:pressed("jump")  -- true only on the first frame
---   tr:down("jump")     -- true while held
---   tr:released("jump") -- true on the release frame

local TouchRegions = {}
TouchRegions.__index = TouchRegions

--- Create a new TouchRegions tracker.
--- @param config table  The ctx.config.input table (action name -> binding)
--- @param opts   table|nil  Optional overrides for testing: { screen_w, screen_h }
--- @return table  TouchRegions instance
function TouchRegions.new(config, opts)
	opts = opts or {}

	local self = setmetatable({}, TouchRegions)

	-- Inject screen dimension provider for testing. In production this calls love.graphics.
	if opts.screen_w and opts.screen_h then
		local sw, sh = opts.screen_w, opts.screen_h
		self._get_dimensions = function()
			return sw, sh
		end
	else
		self._get_dimensions = function()
			return love.graphics.getDimensions()
		end
	end

	-- _regions: array of { action, x, y, w, h, unit, _active_ids, _down, _was_down, _pressed, _released }
	self._regions = {}

	-- Parse config: only actions with a touch field become regions
	for action, binding in pairs(config) do
		if binding.touch then
			local t = binding.touch
			local region = {
				action = action,
				x = t.x or 0,
				y = t.y or 0,
				w = t.w or 0,
				h = t.h or 0,
				unit = t.unit or "px",
				_active_ids = {}, -- set of touch IDs currently inside this region
				_down = false,
				_was_down = false,
				_pressed = false,
				_released = false,
			}
			self._regions[#self._regions + 1] = region
		end
	end

	-- Build a lookup map: action -> region (for fast state queries)
	self._by_action = {}
	for _, region in ipairs(self._regions) do
		self._by_action[region.action] = region
	end

	return self
end

--- Resolve a region's rectangle to pixel coordinates.
--- @param region table  Region definition
--- @return number rx, number ry, number rw, number rh  Pixel coordinates
function TouchRegions:_resolve_rect(region)
	if region.unit == "pct" then
		local sw, sh = self._get_dimensions()
		return region.x * sw, region.y * sh, region.w * sw, region.h * sh
	end
	return region.x, region.y, region.w, region.h
end

--- Called when a touch begins. Checks all regions and marks matching ones active.
--- @param id    any     Touch identifier (love.touch id)
--- @param x     number  Touch x in screen pixels
--- @param y     number  Touch y in screen pixels
function TouchRegions:on_touch_pressed(id, x, y)
	for _, region in ipairs(self._regions) do
		local rx, ry, rw, rh = self:_resolve_rect(region)
		if x >= rx and x < rx + rw and y >= ry and y < ry + rh then
			region._active_ids[id] = true
		end
	end
end

--- Called when a touch ends. Removes the touch ID from ALL regions (no hit test on release).
--- @param id  any  Touch identifier
function TouchRegions:on_touch_released(id)
	for _, region in ipairs(self._regions) do
		region._active_ids[id] = nil
	end
end

--- Compute per-frame pressed/down/released transitions for all regions.
--- Must be called once per frame, after processing all touch events.
function TouchRegions:update()
	for _, region in ipairs(self._regions) do
		region._was_down = region._down
		-- Region is down if any touch ID is active inside it
		region._down = next(region._active_ids) ~= nil
		region._pressed = region._down and not region._was_down
		region._released = not region._down and region._was_down
	end
end

--- Returns true if the touch region for action was just pressed this frame.
--- @param action string  Action name
--- @return boolean
function TouchRegions:pressed(action)
	local region = self._by_action[action]
	if not region then
		return false
	end
	return region._pressed
end

--- Returns true if the touch region for action is currently held down.
--- @param action string  Action name
--- @return boolean
function TouchRegions:down(action)
	local region = self._by_action[action]
	if not region then
		return false
	end
	return region._down
end

--- Returns true if the touch region for action was just released this frame.
--- @param action string  Action name
--- @return boolean
function TouchRegions:released(action)
	local region = self._by_action[action]
	if not region then
		return false
	end
	return region._released
end

--- Return a shallow copy of region definitions for the debug overlay (Phase 6).
--- Each entry: { action, x, y, w, h, unit }
--- @return table[]
function TouchRegions:get_region_defs()
	local defs = {}
	for _, region in ipairs(self._regions) do
		defs[#defs + 1] = {
			action = region.action,
			x = region.x,
			y = region.y,
			w = region.w,
			h = region.h,
			unit = region.unit,
		}
	end
	return defs
end

return TouchRegions
