--- Tests for src/plugins/input/touch_regions.lua
--- Exercises region config parsing, hit testing, and frame state transitions.
--- All tests inject screen dimensions via opts to avoid love.graphics dependency.

local TouchRegions = require("src.plugins.input.touch_regions")

-- Default injected screen size used across tests
local SCREEN_W = 800
local SCREEN_H = 600
local TEST_OPTS = { screen_w = SCREEN_W, screen_h = SCREEN_H }

-- Build a minimal input config with one touch region for a given action
local function make_config_with_touch(action_name, region)
	return {
		[action_name] = {
			key = "space",
			touch = region,
		},
	}
end

describe("TouchRegions", function()
	describe("new()", function()
		it("creates with empty config and produces no regions", function()
			local tr = TouchRegions.new({}, TEST_OPTS)
			assert.are.equal(0, #tr:get_region_defs())
		end)

		it("ignores actions without a touch field", function()
			local config = {
				jump = { key = "space" },
				attack = { gamepad = "a" },
			}
			local tr = TouchRegions.new(config, TEST_OPTS)
			assert.are.equal(0, #tr:get_region_defs())
		end)

		it("creates region defs for actions with touch field", function()
			local config = make_config_with_touch("jump", { x = 10, y = 20, w = 100, h = 50, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)
			local defs = tr:get_region_defs()
			assert.are.equal(1, #defs)
		end)

		it("stores the action name in the region def", function()
			local config = make_config_with_touch("jump", { x = 0, y = 0, w = 100, h = 100, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)
			local defs = tr:get_region_defs()
			assert.are.equal("jump", defs[1].action)
		end)

		it("resolves percentage-based regions correctly", function()
			-- 50% of 800x600 screen
			local config = make_config_with_touch("jump", { x = 0.5, y = 0.5, w = 0.25, h = 0.25, unit = "pct" })
			local tr = TouchRegions.new(config, TEST_OPTS)
			local defs = tr:get_region_defs()
			assert.are.equal(1, #defs)
			-- The region def stores raw config values; resolution happens during hit test
			assert.are.equal("pct", defs[1].unit)
		end)

		it("handles multiple actions each with touch field", function()
			local config = {
				jump = { key = "space", touch = { x = 0, y = 0, w = 100, h = 100, unit = "px" } },
				attack = { key = "z", touch = { x = 200, y = 0, w = 100, h = 100, unit = "px" } },
			}
			local tr = TouchRegions.new(config, TEST_OPTS)
			assert.are.equal(2, #tr:get_region_defs())
		end)
	end)

	describe("on_touch_pressed() and hit testing", function()
		it("marks region active when touch point is inside px region", function()
			-- Region: x=100, y=100, w=200, h=200 (px)
			local config = make_config_with_touch("jump", { x = 100, y = 100, w = 200, h = 200, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 150, 150)
			tr:update()

			assert.is_true(tr:down("jump"))
		end)

		it("does not mark region active when touch point is outside px region", function()
			local config = make_config_with_touch("jump", { x = 100, y = 100, w = 200, h = 200, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 50, 50)
			tr:update()

			assert.is_false(tr:down("jump"))
		end)

		it("marks region active for touch point exactly at top-left corner", function()
			local config = make_config_with_touch("jump", { x = 100, y = 100, w = 200, h = 200, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 100, 100)
			tr:update()

			assert.is_true(tr:down("jump"))
		end)

		it("does not mark region active for touch at right edge (exclusive)", function()
			-- Hit test: x < rx + rw (strictly less than)
			local config = make_config_with_touch("jump", { x = 100, y = 100, w = 200, h = 200, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 300, 150) -- x == rx + rw == 300, should be outside
			tr:update()

			assert.is_false(tr:down("jump"))
		end)

		it("marks region active for touch inside percentage-based region", function()
			-- Region: 50%-75% of 800 wide, 50%-75% of 600 tall
			-- In px: x=400, y=300, w=200, h=150
			local config = make_config_with_touch("jump", { x = 0.5, y = 0.5, w = 0.25, h = 0.25, unit = "pct" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 450, 350) -- inside
			tr:update()

			assert.is_true(tr:down("jump"))
		end)

		it("does not mark active for touch outside percentage-based region", function()
			local config = make_config_with_touch("jump", { x = 0.5, y = 0.5, w = 0.25, h = 0.25, unit = "pct" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 100, 100) -- outside (left/top quadrant)
			tr:update()

			assert.is_false(tr:down("jump"))
		end)
	end)

	describe("on_touch_released()", function()
		it("removes touch id from all regions on release", function()
			local config = {
				jump = { key = "space", touch = { x = 0, y = 0, w = 400, h = 600, unit = "px" } },
				attack = { key = "z", touch = { x = 400, y = 0, w = 400, h = 600, unit = "px" } },
			}
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 200, 300) -- inside "jump" region
			tr:update()
			assert.is_true(tr:down("jump"))

			tr:on_touch_released(1)
			tr:update()

			assert.is_false(tr:down("jump"))
		end)

		it("released removes id regardless of current position", function()
			local config = make_config_with_touch("jump", { x = 0, y = 0, w = 400, h = 600, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 200, 300)
			tr:update()

			-- Release without a hit-test (touch may have moved)
			tr:on_touch_released(1)
			tr:update()

			assert.is_false(tr:down("jump"))
		end)
	end)

	describe("update() frame transitions", function()
		it("pressed() is true only on the first frame a region becomes active", function()
			local config = make_config_with_touch("jump", { x = 0, y = 0, w = 400, h = 600, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 200, 300)

			-- Frame 1: first active frame
			tr:update()
			assert.is_true(tr:pressed("jump"))

			-- Frame 2: still held — pressed should be false
			tr:update()
			assert.is_false(tr:pressed("jump"))
		end)

		it("down() stays true while touch is held across frames", function()
			local config = make_config_with_touch("jump", { x = 0, y = 0, w = 400, h = 600, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 200, 300)

			tr:update()
			assert.is_true(tr:down("jump"))

			tr:update()
			assert.is_true(tr:down("jump"))

			tr:update()
			assert.is_true(tr:down("jump"))
		end)

		it("released() is true only on the frame the touch lifts", function()
			local config = make_config_with_touch("jump", { x = 0, y = 0, w = 400, h = 600, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:on_touch_pressed(1, 200, 300)
			tr:update()
			assert.is_false(tr:released("jump"))

			tr:on_touch_released(1)
			tr:update()
			assert.is_true(tr:released("jump"))

			-- Next frame after release: should be false again
			tr:update()
			assert.is_false(tr:released("jump"))
		end)

		it("all states are false for action with no touch region", function()
			local config = { jump = { key = "space" } } -- no touch field
			local tr = TouchRegions.new(config, TEST_OPTS)

			tr:update()

			assert.is_false(tr:pressed("jump"))
			assert.is_false(tr:down("jump"))
			assert.is_false(tr:released("jump"))
		end)

		it("all states are false for unknown action", function()
			local tr = TouchRegions.new({}, TEST_OPTS)

			tr:update()

			assert.is_false(tr:pressed("nonexistent"))
			assert.is_false(tr:down("nonexistent"))
			assert.is_false(tr:released("nonexistent"))
		end)
	end)

	describe("get_region_defs()", function()
		it("returns a table with region info", function()
			local config = make_config_with_touch("jump", { x = 10, y = 20, w = 100, h = 50, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)
			local defs = tr:get_region_defs()

			assert.is_table(defs)
			assert.is_not_nil(defs[1])
			assert.are.equal("jump", defs[1].action)
			assert.are.equal(10, defs[1].x)
			assert.are.equal(20, defs[1].y)
			assert.are.equal(100, defs[1].w)
			assert.are.equal(50, defs[1].h)
			assert.are.equal("px", defs[1].unit)
		end)

		it("returns a copy so mutations do not affect internal state", function()
			local config = make_config_with_touch("jump", { x = 10, y = 20, w = 100, h = 50, unit = "px" })
			local tr = TouchRegions.new(config, TEST_OPTS)
			local defs = tr:get_region_defs()

			-- Mutate the returned table
			defs[1] = nil

			-- Internal state should be unaffected
			local defs2 = tr:get_region_defs()
			assert.are.equal(1, #defs2)
		end)
	end)
end)
