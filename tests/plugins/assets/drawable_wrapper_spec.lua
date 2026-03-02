-- DrawableWrapper tests.
-- All love.graphics calls are injectable — no Love2D runtime required.
-- Tests both atlas-backed and standalone wrapper paths for every public method.

local DrawableWrapper = require("src.plugins.assets.drawable_wrapper")

-- Helper: create a spy table with a callable __call metamethod.
-- Returns a table (not a bare function) so fields can be set.
local function make_spy()
	local calls = {}
	local spy = setmetatable({}, {
		__call = function(_self, ...)
			calls[#calls + 1] = { ... }
		end,
	})
	spy.calls = calls
	spy.last_call = function()
		return calls[#calls]
	end
	spy.call_count = function()
		return #calls
	end
	return spy
end

-- Stub atlas texture: a table with getDimensions() returning fixed size.
local function make_stub_texture(w, h)
	return {
		getDimensions = function()
			return w, h
		end,
	}
end

-- Stub quad: a table with getViewport() returning fixed coords.
local function make_stub_quad(x, y, w, h)
	return {
		getViewport = function()
			return x, y, w, h
		end,
	}
end

-- Stub standalone asset (image/font/sound): getDimensions() returns size.
local function make_stub_asset(w, h)
	return {
		getDimensions = function()
			return w, h
		end,
	}
end

describe("DrawableWrapper", function()
	describe("from_atlas", function()
		it("creates a wrapper with type 'atlas'", function()
			local texture = make_stub_texture(512, 512)
			local quad = make_stub_quad(0, 0, 32, 32)
			local wrapper = DrawableWrapper.from_atlas(texture, quad)
			assert.equal("atlas", wrapper:get_type())
		end)

		it("stores the texture and quad", function()
			local texture = make_stub_texture(512, 512)
			local quad = make_stub_quad(10, 20, 64, 64)
			local wrapper = DrawableWrapper.from_atlas(texture, quad)
			assert.equal(texture, wrapper:get_texture())
			assert.equal(quad, wrapper:get_quad())
		end)
	end)

	describe("from_standalone", function()
		it("creates a wrapper with type 'standalone'", function()
			local asset = make_stub_asset(256, 256)
			local wrapper = DrawableWrapper.from_standalone(asset)
			assert.equal("standalone", wrapper:get_type())
		end)

		it("stores the asset", function()
			local asset = make_stub_asset(128, 64)
			local wrapper = DrawableWrapper.from_standalone(asset)
			assert.equal(asset, wrapper:get_texture())
		end)

		it("get_quad returns nil for standalone", function()
			local asset = make_stub_asset(128, 64)
			local wrapper = DrawableWrapper.from_standalone(asset)
			assert.is_nil(wrapper:get_quad())
		end)
	end)

	describe("draw (atlas)", function()
		it("calls draw_fn with (texture, quad, x, y, r, sx, sy)", function()
			local texture = make_stub_texture(512, 512)
			local quad = make_stub_quad(0, 0, 32, 32)
			local draw_spy = make_spy()
			local wrapper = DrawableWrapper.from_atlas(texture, quad, { draw_fn = draw_spy })

			wrapper:draw(10, 20, 0.5, 2, 3)

			assert.equal(1, draw_spy.call_count())
			local args = draw_spy.last_call()
			assert.equal(texture, args[1])
			assert.equal(quad, args[2])
			assert.equal(10, args[3])
			assert.equal(20, args[4])
			assert.equal(0.5, args[5])
			assert.equal(2, args[6])
			assert.equal(3, args[7])
		end)

		it("defaults r, sx, sy to nil when not provided", function()
			local texture = make_stub_texture(512, 512)
			local quad = make_stub_quad(0, 0, 32, 32)
			local draw_spy = make_spy()
			local wrapper = DrawableWrapper.from_atlas(texture, quad, { draw_fn = draw_spy })

			wrapper:draw(5, 10)

			local args = draw_spy.last_call()
			assert.equal(5, args[3])
			assert.equal(10, args[4])
			-- r, sx, sy all nil
			assert.is_nil(args[5])
			assert.is_nil(args[6])
			assert.is_nil(args[7])
		end)
	end)

	describe("draw (standalone)", function()
		it("calls draw_fn with (asset, x, y, r, sx, sy)", function()
			local asset = make_stub_asset(256, 256)
			local draw_spy = make_spy()
			local wrapper = DrawableWrapper.from_standalone(asset, { draw_fn = draw_spy })

			wrapper:draw(100, 200, 1.5, 0.5, 0.5)

			assert.equal(1, draw_spy.call_count())
			local args = draw_spy.last_call()
			assert.equal(asset, args[1])
			assert.equal(100, args[2])
			assert.equal(200, args[3])
			assert.equal(1.5, args[4])
			assert.equal(0.5, args[5])
			assert.equal(0.5, args[6])
		end)

		it("defaults r, sx, sy to nil when not provided", function()
			local asset = make_stub_asset(256, 256)
			local draw_spy = make_spy()
			local wrapper = DrawableWrapper.from_standalone(asset, { draw_fn = draw_spy })

			wrapper:draw(0, 0)

			local args = draw_spy.last_call()
			assert.is_nil(args[4])
			assert.is_nil(args[5])
			assert.is_nil(args[6])
		end)
	end)

	describe("get_dimensions (atlas)", function()
		it("returns quad viewport width and height", function()
			local texture = make_stub_texture(512, 512)
			local quad = make_stub_quad(10, 20, 48, 64)
			local wrapper = DrawableWrapper.from_atlas(texture, quad)

			local w, h = wrapper:get_dimensions()
			assert.equal(48, w)
			assert.equal(64, h)
		end)
	end)

	describe("get_dimensions (standalone)", function()
		it("calls get_dimensions_fn on the asset", function()
			local asset = make_stub_asset(320, 240)
			local get_dims_spy = make_spy()

			-- Inject a custom get_dimensions_fn that delegates to asset:getDimensions()
			local wrapper = DrawableWrapper.from_standalone(asset, {
				get_dimensions_fn = function(a)
					get_dims_spy(a)
					return a:getDimensions()
				end,
			})

			local w, h = wrapper:get_dimensions()
			assert.equal(320, w)
			assert.equal(240, h)
			assert.equal(1, get_dims_spy.call_count())
		end)

		it("returns correct dimensions from asset", function()
			local asset = make_stub_asset(800, 600)
			local wrapper = DrawableWrapper.from_standalone(asset, {
				get_dimensions_fn = function(a)
					return a:getDimensions()
				end,
			})

			local w, h = wrapper:get_dimensions()
			assert.equal(800, w)
			assert.equal(600, h)
		end)
	end)

	describe("get_type", function()
		it("returns 'atlas' for atlas wrapper", function()
			local texture = make_stub_texture(512, 512)
			local quad = make_stub_quad(0, 0, 32, 32)
			local wrapper = DrawableWrapper.from_atlas(texture, quad)
			assert.equal("atlas", wrapper:get_type())
		end)

		it("returns 'standalone' for standalone wrapper", function()
			local asset = make_stub_asset(64, 64)
			local wrapper = DrawableWrapper.from_standalone(asset)
			assert.equal("standalone", wrapper:get_type())
		end)
	end)
end)
