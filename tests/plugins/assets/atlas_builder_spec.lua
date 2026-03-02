-- AtlasBuilder tests.
-- Pure Lua — no Love2D runtime required.
-- Tests group packing, auto-split on oversized groups, and DrawableWrapper creation.
-- Uses RTA stub, love.graphics stub, and DrawableWrapper (real module with injectable fns).

local AtlasBuilder = require("src.plugins.assets.atlas_builder")
local DrawableWrapper = require("src.plugins.assets.drawable_wrapper")

-- Build an RTA (TA) stub that records calls and returns deterministic viewports.
local function make_ta_stub()
	local stub = {}

	function stub.newDynamicSize(padding, extrude, spacing)
		local atlas = {
			_images = {},
			_max_w = nil,
			_max_h = nil,
			_baked = false,
			_sort = nil,
			_padding = padding,
			_extrude = extrude,
			_spacing = spacing,
			-- Expose a canvas-like object for tests
			_canvas = nil,
		}

		function atlas:setMaxSize(w, h)
			self._max_w = w
			self._max_h = h
		end

		function atlas:add(image, key)
			self._images[key] = image
		end

		function atlas:bake(sort)
			self._baked = true
			self._sort = sort
			-- Create a fake canvas after baking
			self._canvas = {
				_type = "canvas",
				getDimensions = function()
					return 512, 512
				end,
			}
		end

		function atlas:getViewport(key)
			-- Return deterministic test values: all sprites 32x32 at origin
			return 0, 0, 32, 32
		end

		-- Public accessor (mirrors what real RTA may expose)
		function atlas:getCanvas()
			return self._canvas
		end

		return atlas
	end

	return stub
end

-- Build a love.graphics stub with newQuad.
local function make_love_graphics_stub()
	local stub = {}

	function stub.newQuad(x, y, w, h, sw, sh)
		return {
			_type = "quad",
			_x = x,
			_y = y,
			_w = w,
			_h = h,
			_sw = sw,
			_sh = sh,
			-- Simulate getViewport() so DrawableWrapper:get_dimensions() works
			getViewport = function(self_q)
				return self_q._x, self_q._y, self_q._w, self_q._h
			end,
		}
	end

	return stub
end

-- Build a fake image with configurable dimensions.
local function make_fake_image(w, h)
	return {
		_type = "image",
		_w = w,
		_h = h,
		getDimensions = function(self_img)
			return self_img._w, self_img._h
		end,
	}
end

describe("AtlasBuilder", function()
	describe("construction", function()
		it("creates an AtlasBuilder with injected stubs", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({ ta = ta, love_graphics = love_graphics, drawable_wrapper = DrawableWrapper })
			assert.not_nil(builder)
		end)

		it("get_all_atlases returns empty table initially", function()
			local builder = AtlasBuilder.new({
				ta = make_ta_stub(),
				love_graphics = make_love_graphics_stub(),
				drawable_wrapper = DrawableWrapper,
			})
			assert.same({}, builder:get_all_atlases())
		end)
	end)

	describe("build: normal group packing", function()
		it("creates an atlas for each group", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
			})

			local groups = {
				sprites = { "player_idle", "player_run" },
			}
			local loaded_images = {
				player_idle = make_fake_image(32, 32),
				player_run  = make_fake_image(32, 32),
			}

			local atlases = builder:build(groups, loaded_images)

			assert.not_nil(atlases["sprites"])
		end)

		it("stores DrawableWrapper for each key in the group", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
			})

			local groups = {
				sprites = { "player_idle", "player_run" },
			}
			local loaded_images = {
				player_idle = make_fake_image(32, 32),
				player_run  = make_fake_image(32, 32),
			}

			local atlases = builder:build(groups, loaded_images)

			assert.not_nil(atlases["sprites"].wrappers)
			assert.not_nil(atlases["sprites"].wrappers["player_idle"])
			assert.not_nil(atlases["sprites"].wrappers["player_run"])
		end)

		it("wrappers are DrawableWrapper instances of type 'atlas'", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
			})

			local groups = { sprites = { "player_idle" } }
			local loaded_images = { player_idle = make_fake_image(32, 32) }

			local atlases = builder:build(groups, loaded_images)
			local wrapper = atlases["sprites"].wrappers["player_idle"]

			assert.equal("atlas", wrapper:get_type())
		end)

		it("atlas canvas is stored in atlases result", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
			})

			local groups = { sprites = { "player_idle" } }
			local loaded_images = { player_idle = make_fake_image(32, 32) }

			local atlases = builder:build(groups, loaded_images)
			assert.not_nil(atlases["sprites"].canvas)
		end)

		it("packs images from a single-image group", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
			})

			local groups = { solo = { "lone_sprite" } }
			local loaded_images = { lone_sprite = make_fake_image(64, 64) }

			local atlases = builder:build(groups, loaded_images)

			assert.not_nil(atlases["solo"])
			assert.not_nil(atlases["solo"].wrappers["lone_sprite"])
		end)

		it("handles multiple groups independently", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
			})

			local groups = {
				sprites = { "player_idle" },
				enemies = { "enemy_walk" },
			}
			local loaded_images = {
				player_idle = make_fake_image(32, 32),
				enemy_walk  = make_fake_image(48, 48),
			}

			local atlases = builder:build(groups, loaded_images)

			assert.not_nil(atlases["sprites"])
			assert.not_nil(atlases["enemies"])
		end)

		it("build returns same table as get_all_atlases()", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
			})

			local groups = { sprites = { "player_idle" } }
			local loaded_images = { player_idle = make_fake_image(32, 32) }

			local result = builder:build(groups, loaded_images)
			assert.equal(result, builder:get_all_atlases())
		end)

		it("get_atlas(group_name) returns the atlas for that group", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
			})

			local groups = { sprites = { "player_idle" } }
			local loaded_images = { player_idle = make_fake_image(32, 32) }

			builder:build(groups, loaded_images)
			local atlas = builder:get_atlas("sprites")

			assert.not_nil(atlas)
			assert.not_nil(atlas.wrappers["player_idle"])
		end)

		it("empty groups table produces empty atlases", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
			})

			local atlases = builder:build({}, {})
			assert.same({}, atlases)
		end)
	end)

	describe("build: auto-split on oversized groups", function()
		it("splits a group whose total area exceeds max_size^2", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local log_messages = {}
			local function capture_log(msg)
				table.insert(log_messages, msg)
			end

			-- max_size=64 means budget = 64*64 = 4096 pixels
			-- Three 48x48 images: 48*48=2304 each, total=6912 > 4096 -> split needed
			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
				max_size = 64,
				log = capture_log,
			})

			local groups = {
				sprites = { "a", "b", "c" },
			}
			local loaded_images = {
				a = make_fake_image(48, 48),
				b = make_fake_image(48, 48),
				c = make_fake_image(48, 48),
			}

			local atlases = builder:build(groups, loaded_images)

			-- After split, we expect multiple sub-atlas keys for "sprites"
			-- They will be named "sprites_1", "sprites_2", etc.
			local sub_atlas_count = 0
			for k, _ in pairs(atlases) do
				if k:find("^sprites") then
					sub_atlas_count = sub_atlas_count + 1
				end
			end
			assert.is_true(sub_atlas_count > 1)
		end)

		it("emits a warning when auto-split occurs", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local log_messages = {}
			local function capture_log(msg)
				table.insert(log_messages, msg)
			end

			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
				max_size = 64,
				log = capture_log,
			})

			local groups = { sprites = { "a", "b", "c" } }
			local loaded_images = {
				a = make_fake_image(48, 48),
				b = make_fake_image(48, 48),
				c = make_fake_image(48, 48),
			}

			builder:build(groups, loaded_images)

			-- Should have logged at least one warning mentioning "sprites" and "split"
			local found_warning = false
			for _, msg in ipairs(log_messages) do
				if msg:find("sprites") and msg:find("split") then
					found_warning = true
				end
			end
			assert.is_true(found_warning, "Expected a split warning mentioning group name 'sprites'")
		end)

		it("all keys are still accessible after auto-split", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local log_messages = {}

			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
				max_size = 64,
				log = function(msg)
					table.insert(log_messages, msg)
				end,
			})

			local groups = { sprites = { "a", "b", "c" } }
			local loaded_images = {
				a = make_fake_image(48, 48),
				b = make_fake_image(48, 48),
				c = make_fake_image(48, 48),
			}

			local atlases = builder:build(groups, loaded_images)

			-- Collect all wrappers from all sub-atlases
			local found_keys = {}
			for _, atlas_data in pairs(atlases) do
				for key, _ in pairs(atlas_data.wrappers) do
					found_keys[key] = true
				end
			end

			assert.is_true(found_keys["a"], "key 'a' should be in a sub-atlas")
			assert.is_true(found_keys["b"], "key 'b' should be in a sub-atlas")
			assert.is_true(found_keys["c"], "key 'c' should be in a sub-atlas")
		end)

		it("does NOT split a group whose total area fits within budget", function()
			local ta = make_ta_stub()
			local love_graphics = make_love_graphics_stub()
			local log_messages = {}

			local builder = AtlasBuilder.new({
				ta = ta,
				love_graphics = love_graphics,
				drawable_wrapper = DrawableWrapper,
				max_size = 256,
				log = function(msg)
					table.insert(log_messages, msg)
				end,
			})

			-- 2 images of 32x32 = 2048 total area; budget = 256*256 = 65536 — fits easily
			local groups = { sprites = { "a", "b" } }
			local loaded_images = {
				a = make_fake_image(32, 32),
				b = make_fake_image(32, 32),
			}

			local atlases = builder:build(groups, loaded_images)

			-- Should be exactly one atlas named "sprites" — no split
			assert.not_nil(atlases["sprites"], "No split expected; 'sprites' should be a single atlas")
			-- No warning should have been logged
			assert.equal(0, #log_messages, "No split warning expected")
		end)
	end)
end)
