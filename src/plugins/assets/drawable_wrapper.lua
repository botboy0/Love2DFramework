--- DrawableWrapper: uniform drawable API for atlas-backed and standalone assets.
---
--- Usage:
---   local DrawableWrapper = require("src.plugins.assets.drawable_wrapper")
---
---   -- Atlas-backed sprite (packed into a texture atlas):
---   local wrapper = DrawableWrapper.from_atlas(atlas_texture, quad, opts)
---
---   -- Standalone asset (image, font, sound):
---   local wrapper = DrawableWrapper.from_standalone(asset, opts)
---
---   -- Both types share the same draw API:
---   wrapper:draw(x, y, r, sx, sy)
---   wrapper:get_texture()    -- atlas texture or standalone asset
---   wrapper:get_quad()       -- quad for atlas, nil for standalone
---   wrapper:get_dimensions() -- width, height regardless of type
---   wrapper:get_type()       -- "atlas" or "standalone"
---
--- Dependency injection via opts:
---   opts.draw_fn             -- replaces love.graphics.draw for testing
---   opts.get_dimensions_fn   -- replaces asset:getDimensions() for testing (standalone only)
---
--- Pure Lua with injectable Love2D calls — no Love2D runtime required in tests.

local DrawableWrapper = {}
DrawableWrapper.__index = DrawableWrapper

--- Default draw function falls back to love.graphics.draw at call time.
--- Using a closure avoids requiring love at module load (love may not exist in tests).
local function default_draw_fn(...)
	return love.graphics.draw(...)
end

--- Default get_dimensions for standalone: calls asset:getDimensions().
local function default_get_dimensions_fn(asset)
	return asset:getDimensions()
end

--- Create an atlas-backed wrapper.
--- @param atlas_texture table  The atlas canvas/texture (love.graphics.Canvas or Image)
--- @param quad          table  The quad for this sprite's region in the atlas
--- @param opts          table|nil  Optional { draw_fn, get_dimensions_fn }
--- @return DrawableWrapper
function DrawableWrapper.from_atlas(atlas_texture, quad, opts)
	opts = opts or {}
	return setmetatable({
		_type = "atlas",
		_texture = atlas_texture,
		_quad = quad,
		_draw_fn = opts.draw_fn or default_draw_fn,
	}, DrawableWrapper)
end

--- Create a standalone wrapper (image, font, sound — not atlas-packed).
--- @param asset  table  The standalone asset (love.graphics.Image, Font, Source, etc.)
--- @param opts   table|nil  Optional { draw_fn, get_dimensions_fn }
--- @return DrawableWrapper
function DrawableWrapper.from_standalone(asset, opts)
	opts = opts or {}
	return setmetatable({
		_type = "standalone",
		_asset = asset,
		_draw_fn = opts.draw_fn or default_draw_fn,
		_get_dimensions_fn = opts.get_dimensions_fn or default_get_dimensions_fn,
	}, DrawableWrapper)
end

--- Draw the asset at (x, y) with optional rotation and scale.
--- Atlas path: draw_fn(texture, quad, x, y, r, sx, sy)
--- Standalone path: draw_fn(asset, x, y, r, sx, sy)
--- @param x  number  World x position
--- @param y  number  World y position
--- @param r  number|nil  Rotation in radians (default nil)
--- @param sx number|nil  X scale (default nil)
--- @param sy number|nil  Y scale (default nil)
function DrawableWrapper:draw(x, y, r, sx, sy)
	if self._type == "atlas" then
		self._draw_fn(self._texture, self._quad, x, y, r, sx, sy)
	else
		self._draw_fn(self._asset, x, y, r, sx, sy)
	end
end

--- Return the underlying texture or asset.
--- Atlas: returns the atlas canvas/texture.
--- Standalone: returns the asset (image, font, sound).
--- @return table
function DrawableWrapper:get_texture()
	if self._type == "atlas" then
		return self._texture
	else
		return self._asset
	end
end

--- Return the quad for atlas wrappers, nil for standalone.
--- @return table|nil
function DrawableWrapper:get_quad()
	return self._quad
end

--- Return width and height of the drawable region.
--- Atlas: reads from quad viewport (w, h from getViewport()).
--- Standalone: calls get_dimensions_fn(asset).
--- @return number w, number h
function DrawableWrapper:get_dimensions()
	if self._type == "atlas" then
		local _x, _y, w, h = self._quad:getViewport()
		return w, h
	else
		return self._get_dimensions_fn(self._asset)
	end
end

--- Return the wrapper type.
--- @return "atlas"|"standalone"
function DrawableWrapper:get_type()
	return self._type
end

return DrawableWrapper
