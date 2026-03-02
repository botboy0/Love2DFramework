--- Tests for src/plugins/input/init.lua
--- Exercises plugin lifecycle, service API, and bus event emission.
--- Physical devices are never required — mock baton player and touch regions are injected.

local InputPlugin = require("src.plugins.input")
local harness = require("tests.helpers.plugin_harness")

--- Build a minimal mock baton player.
--- Callers can override any field to simulate input state.
--- @param overrides table Optional field overrides
--- @return table Mock baton player
local function make_mock_player(overrides)
	local player = {
		_active_device = "none",
		_pressed = {},
		_down = {},
		_released = {},
		update = function(_self) end,
		down = function(self, action)
			return self._down[action] or false
		end,
		pressed = function(self, action)
			return self._pressed[action] or false
		end,
		released = function(self, action)
			return self._released[action] or false
		end,
		get = function(_self, _action)
			return 0
		end,
		getActiveDevice = function(self)
			return self._active_device
		end,
		config = { joystick = nil },
	}
	if overrides then
		for k, v in pairs(overrides) do
			player[k] = v
		end
	end
	return player
end

--- Build a minimal mock TouchRegions object.
--- @param overrides table Optional field overrides
--- @return table Mock touch regions
local function make_mock_touch_regions(overrides)
	local tr = {
		update = function(_self) end,
		down = function(_self, _action)
			return false
		end,
		pressed = function(_self, _action)
			return false
		end,
		released = function(_self, _action)
			return false
		end,
		on_touch_pressed = function(_self, _id, _x, _y) end,
		on_touch_released = function(_self, _id) end,
		get_region_defs = function(_self)
			return {}
		end,
	}
	if overrides then
		for k, v in pairs(overrides) do
			tr[k] = v
		end
	end
	return tr
end

--- Reset plugin singleton state between tests.
local function reset_plugin()
	InputPlugin._bus = nil
	InputPlugin._player = nil
	InputPlugin._touch_regions = nil
	InputPlugin._actions = nil
	InputPlugin._last_device = nil
	InputPlugin._joystick = nil
end

describe("InputPlugin", function()
	local ctx

	before_each(function()
		ctx = harness.create_context({
			config = {
				input = {
					jump = { key = "space", gamepad = "a" },
					fire = { key = "z", gamepad = "x" },
				},
			},
		})
		reset_plugin()
	end)

	after_each(function()
		harness.teardown(ctx)
	end)

	describe("plugin metadata", function()
		it("has name 'input'", function()
			assert.are.equal("input", InputPlugin.name)
		end)

		it("has empty deps table", function()
			assert.is_table(InputPlugin.deps)
			assert.are.equal(0, #InputPlugin.deps)
		end)
	end)

	describe("init()", function()
		it("succeeds with empty config (no actions)", function()
			local empty_ctx = harness.create_context({ config = {} })
			assert.has_no_error(function()
				InputPlugin:init(empty_ctx)
			end)
			harness.teardown(empty_ctx)
		end)

		it("succeeds with action bindings in config", function()
			assert.has_no_error(function()
				InputPlugin:init(ctx)
			end)
		end)

		it("registers 'input' service", function()
			InputPlugin:init(ctx)
			local svc = ctx.services:get("input")
			assert.is_not_nil(svc)
		end)

		it("service exposes is_down", function()
			InputPlugin:init(ctx)
			local svc = ctx.services:get("input")
			assert.is_function(svc.is_down)
		end)

		it("service exposes is_pressed", function()
			InputPlugin:init(ctx)
			local svc = ctx.services:get("input")
			assert.is_function(svc.is_pressed)
		end)

		it("service exposes is_released", function()
			InputPlugin:init(ctx)
			local svc = ctx.services:get("input")
			assert.is_function(svc.is_released)
		end)

		it("service exposes get_axis", function()
			InputPlugin:init(ctx)
			local svc = ctx.services:get("input")
			assert.is_function(svc.get_axis)
		end)

		it("service exposes get_active_device", function()
			InputPlugin:init(ctx)
			local svc = ctx.services:get("input")
			assert.is_function(svc.get_active_device)
		end)

		it("service exposes get_touch_points", function()
			InputPlugin:init(ctx)
			local svc = ctx.services:get("input")
			assert.is_function(svc.get_touch_points)
		end)

		it("service exposes get_touch_regions", function()
			InputPlugin:init(ctx)
			local svc = ctx.services:get("input")
			assert.is_function(svc.get_touch_regions)
		end)
	end)

	describe("service API with mock player", function()
		it("is_pressed returns true when mock player reports pressed", function()
			InputPlugin:init(ctx)
			local mock_player = make_mock_player({ _pressed = { jump = true } })
			InputPlugin._player = mock_player

			local svc = ctx.services:get("input")
			assert.is_true(svc.is_pressed("jump"))
		end)

		it("is_pressed returns false for action not pressed", function()
			InputPlugin:init(ctx)
			local mock_player = make_mock_player()
			InputPlugin._player = mock_player

			local svc = ctx.services:get("input")
			assert.is_false(svc.is_pressed("jump"))
		end)

		it("is_down returns true when mock player reports down", function()
			InputPlugin:init(ctx)
			local mock_player = make_mock_player({ _down = { jump = true } })
			InputPlugin._player = mock_player

			local svc = ctx.services:get("input")
			assert.is_true(svc.is_down("jump"))
		end)

		it("is_down returns true when touch_regions reports down (OR logic)", function()
			InputPlugin:init(ctx)
			InputPlugin._player = make_mock_player() -- player: not down
			InputPlugin._touch_regions = make_mock_touch_regions({
				down = function(_self, action)
					return action == "jump"
				end,
			})

			local svc = ctx.services:get("input")
			assert.is_true(svc.is_down("jump"))
		end)

		it("get_active_device returns mock player device", function()
			InputPlugin:init(ctx)
			InputPlugin._player = make_mock_player({ _active_device = "kbm" })

			local svc = ctx.services:get("input")
			assert.are.equal("kbm", svc.get_active_device())
		end)

		it("get_touch_points returns empty table when love.touch unavailable", function()
			InputPlugin:init(ctx)

			-- love.touch is not available in test environment
			local svc = ctx.services:get("input")
			local pts = svc.get_touch_points()
			assert.is_table(pts)
		end)

		it("get_touch_regions returns region defs table", function()
			InputPlugin:init(ctx)
			InputPlugin._touch_regions = make_mock_touch_regions()

			local svc = ctx.services:get("input")
			local defs = svc.get_touch_regions()
			assert.is_table(defs)
		end)
	end)

	describe("update() bus events", function()
		it("emits input:action_pressed when action transitions to pressed", function()
			InputPlugin:init(ctx)

			-- Inject mock player that reports "jump" as pressed
			local mock_player = make_mock_player({ _pressed = { jump = true }, _active_device = "kbm" })
			InputPlugin._player = mock_player
			InputPlugin._touch_regions = make_mock_touch_regions()

			local received = {}
			ctx.bus:on("input:action_pressed", function(data)
				table.insert(received, data)
			end)

			InputPlugin:update(0)
			ctx.bus:flush()

			assert.are.equal(1, #received)
			assert.are.equal("jump", received[1].action)
			assert.are.equal("kbm", received[1].device)
		end)

		it("emits input:action_released when action transitions to released", function()
			InputPlugin:init(ctx)

			local mock_player = make_mock_player({ _released = { fire = true }, _active_device = "kbm" })
			InputPlugin._player = mock_player
			InputPlugin._touch_regions = make_mock_touch_regions()

			local received = {}
			ctx.bus:on("input:action_released", function(data)
				table.insert(received, data)
			end)

			InputPlugin:update(0)
			ctx.bus:flush()

			assert.are.equal(1, #received)
			assert.are.equal("fire", received[1].action)
		end)

		it("emits input:device_changed when active device changes", function()
			InputPlugin:init(ctx)

			-- Start device as "none", then switch to "kbm"
			local mock_player = make_mock_player({ _active_device = "none" })
			InputPlugin._player = mock_player
			InputPlugin._last_device = "none"
			InputPlugin._touch_regions = make_mock_touch_regions()

			local received = {}
			ctx.bus:on("input:device_changed", function(data)
				table.insert(received, data)
			end)

			-- Simulate device switch
			mock_player._active_device = "kbm"
			InputPlugin:update(0)
			ctx.bus:flush()

			assert.are.equal(1, #received)
			assert.are.equal("kbm", received[1].device)
		end)

		it("does not emit input:device_changed when device stays the same", function()
			InputPlugin:init(ctx)

			local mock_player = make_mock_player({ _active_device = "kbm" })
			InputPlugin._player = mock_player
			InputPlugin._last_device = "kbm"
			InputPlugin._touch_regions = make_mock_touch_regions()

			local count = 0
			ctx.bus:on("input:device_changed", function(_data)
				count = count + 1
			end)

			InputPlugin:update(0)
			ctx.bus:flush()

			assert.are.equal(0, count)
		end)

		it("does not emit events for actions with no state changes", function()
			InputPlugin:init(ctx)

			local mock_player = make_mock_player({ _active_device = "none" })
			InputPlugin._player = mock_player
			InputPlugin._last_device = "none"
			InputPlugin._touch_regions = make_mock_touch_regions()

			local count = 0
			ctx.bus:on("input:action_pressed", function(_data)
				count = count + 1
			end)
			ctx.bus:on("input:action_released", function(_data)
				count = count + 1
			end)

			InputPlugin:update(0)
			ctx.bus:flush()

			assert.are.equal(0, count)
		end)
	end)

	describe("joystick callbacks", function()
		it("on_joystick_added emits input:gamepad_connected for gamepad joystick", function()
			InputPlugin:init(ctx)
			InputPlugin._player = make_mock_player()
			InputPlugin._touch_regions = make_mock_touch_regions()

			local received = {}
			ctx.bus:on("input:gamepad_connected", function(data)
				table.insert(received, data)
			end)

			local mock_joystick = {
				isGamepad = function(_self) return true end,
			}

			InputPlugin:on_joystick_added(mock_joystick)
			ctx.bus:flush()

			assert.are.equal(1, #received)
		end)

		it("on_joystick_added does not emit for non-gamepad joystick", function()
			InputPlugin:init(ctx)
			InputPlugin._player = make_mock_player()

			local count = 0
			ctx.bus:on("input:gamepad_connected", function(_data)
				count = count + 1
			end)

			local mock_joystick = {
				isGamepad = function(_self) return false end,
			}

			InputPlugin:on_joystick_added(mock_joystick)
			ctx.bus:flush()

			assert.are.equal(0, count)
		end)

		it("on_joystick_removed emits input:gamepad_disconnected", function()
			InputPlugin:init(ctx)
			InputPlugin._player = make_mock_player()
			InputPlugin._touch_regions = make_mock_touch_regions()

			-- First add a joystick
			local mock_joystick = {
				isGamepad = function(_self) return true end,
			}
			InputPlugin:on_joystick_added(mock_joystick)

			local received = {}
			ctx.bus:on("input:gamepad_disconnected", function(data)
				table.insert(received, data)
			end)

			InputPlugin:on_joystick_removed(mock_joystick)
			ctx.bus:flush()

			assert.are.equal(1, #received)
		end)

		it("on_joystick_removed does not emit for unknown joystick", function()
			InputPlugin:init(ctx)
			InputPlugin._player = make_mock_player()

			local count = 0
			ctx.bus:on("input:gamepad_disconnected", function(_data)
				count = count + 1
			end)

			local other_joystick = { isGamepad = function(_self) return true end }
			InputPlugin:on_joystick_removed(other_joystick)
			ctx.bus:flush()

			assert.are.equal(0, count)
		end)
	end)

	describe("touch forwarding", function()
		it("on_touch_pressed forwards to touch_regions", function()
			InputPlugin:init(ctx)

			local calls = {}
			InputPlugin._touch_regions = make_mock_touch_regions({
				on_touch_pressed = function(_self, id, x, y)
					table.insert(calls, { id = id, x = x, y = y })
				end,
			})

			InputPlugin:on_touch_pressed(42, 100, 200)

			assert.are.equal(1, #calls)
			assert.are.equal(42, calls[1].id)
			assert.are.equal(100, calls[1].x)
			assert.are.equal(200, calls[1].y)
		end)

		it("on_touch_released forwards to touch_regions", function()
			InputPlugin:init(ctx)

			local calls = {}
			InputPlugin._touch_regions = make_mock_touch_regions({
				on_touch_released = function(_self, id)
					table.insert(calls, { id = id })
				end,
			})

			InputPlugin:on_touch_released(42, 100, 200)

			assert.are.equal(1, #calls)
			assert.are.equal(42, calls[1].id)
		end)
	end)

	describe("shutdown()", function()
		it("is callable without error", function()
			InputPlugin:init(ctx)
			assert.has_no_error(function()
				InputPlugin:shutdown(ctx)
			end)
		end)
	end)
end)
