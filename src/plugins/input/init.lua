--- Input Plugin
--- Provides unified keyboard, gamepad, and touch input via baton + touch regions.
---
--- Registers the "input" service for polling input state:
---   is_down(action), is_pressed(action), is_released(action)
---   get_axis(action), get_active_device()
---   get_touch_points(), get_touch_regions()
---
--- Emits bus events for discrete transitions:
---   input:action_pressed   { action, device }
---   input:action_released  { action, device }
---   input:device_changed   { device }
---   input:gamepad_connected    {}
---   input:gamepad_disconnected {}
---
--- Config keys (under ctx.config.input):
---   action_name = {
---     key         = "space" | { "space", "w" }   -- keyboard keys
---     sc          = "space"  | { ... }            -- scancodes
---     gamepad     = "a"      | { "a", "b" }       -- gamepad buttons
---     gamepad_axis = "leftx+" | { ... }           -- analog axes
---     touch       = { x, y, w, h, unit = "px"|"pct" }  -- touch region
---   }
---
--- Follow canonical_plugin.lua pattern exactly.
--- See CLAUDE.md for architectural rules.

local TouchRegions = require("src.plugins.input.touch_regions")
local baton = require("lib.baton")

local InputPlugin = {}
InputPlugin.__index = InputPlugin

--- Plugin metadata
InputPlugin.name = "input"
InputPlugin.deps = {}

--- Translate a single binding value (string or table) into baton source strings.
--- Prefix is the baton source type prefix (e.g. "key:", "button:", "axis:", "sc:").
--- @param value  string|table  Single string or array of strings
--- @param prefix string        Baton source prefix
--- @param out    table         Destination array to append into
local function append_sources(value, prefix, out)
	if type(value) == "string" then
		out[#out + 1] = prefix .. value
	elseif type(value) == "table" then
		for _, v in ipairs(value) do
			out[#out + 1] = prefix .. v
		end
	end
end

--- Translate the input config table to baton's controls format.
--- Returns baton_controls and a set of action names.
--- @param input_config table  ctx.config.input
--- @return table baton_controls, table actions_set
local function translate_config(input_config)
	local baton_controls = {}
	local actions_set = {}

	for action, binding in pairs(input_config) do
		local sources = {}

		if binding.key then
			append_sources(binding.key, "key:", sources)
		end
		if binding.sc then
			append_sources(binding.sc, "sc:", sources)
		end
		if binding.gamepad then
			append_sources(binding.gamepad, "button:", sources)
		end
		if binding.gamepad_axis then
			append_sources(binding.gamepad_axis, "axis:", sources)
		end

		-- Only register the action with baton if it has non-touch sources.
		-- Touch-only actions are handled exclusively via TouchRegions.
		if #sources > 0 then
			baton_controls[action] = sources
		end

		-- Always track the action name for event emission
		actions_set[action] = true
	end

	return baton_controls, actions_set
end

--- Initialize the input plugin.
--- @param ctx table  { worlds, bus, config, services, transport }
function InputPlugin:init(ctx)
	self._bus = ctx.bus

	local input_config = (ctx.config and ctx.config.input) or {}

	-- Translate config to baton format
	local baton_controls, actions_set = translate_config(input_config)
	self._actions = actions_set

	-- Create baton player. Baton requires at least the controls key.
	self._player = baton.new({
		controls = baton_controls,
		deadzone = (ctx.config and ctx.config.input_deadzone) or 0.2,
	})

	-- Create touch regions (opts nil in production — uses love.graphics)
	self._touch_regions = TouchRegions.new(input_config)

	-- Track last active device for change detection
	self._last_device = self._player:getActiveDevice()

	-- No joystick connected initially
	self._joystick = nil

	-- Register "input" service
	-- Service methods are plain functions (not methods) — callers use svc.is_down("jump")
	ctx.services:register("input", {
		is_down = function(action)
			return self:_is_down(action)
		end,
		is_pressed = function(action)
			return self:_is_pressed(action)
		end,
		is_released = function(action)
			return self:_is_released(action)
		end,
		get_axis = function(action)
			return self._player:get(action)
		end,
		get_active_device = function()
			return self._player:getActiveDevice()
		end,
		get_touch_points = function()
			-- love.touch may be unavailable in tests or on non-touch platforms
			if love and love.touch then
				return love.touch.getTouches()
			end
			return {}
		end,
		get_touch_regions = function()
			return self._touch_regions:get_region_defs()
		end,
	})
end

--- Per-frame update: poll baton, compute touch transitions, emit bus events.
--- @param _dt number  Delta time (unused — baton handles its own timing)
function InputPlugin:update(_dt)
	-- 1. Update baton player (reads physical device state)
	self._player:update()

	-- 2. Update touch region frame transitions
	self._touch_regions:update()

	-- 3. Emit discrete action events
	for action in pairs(self._actions) do
		if self:_is_pressed(action) then
			self._bus:emit("input:action_pressed", {
				action = action,
				device = self._player:getActiveDevice(),
			})
		end
		if self:_is_released(action) then
			self._bus:emit("input:action_released", {
				action = action,
				device = self._player:getActiveDevice(),
			})
		end
	end

	-- 4. Device change detection
	local current = self._player:getActiveDevice()
	if current ~= self._last_device then
		self._bus:emit("input:device_changed", { device = current })
		self._last_device = current
	end
end

--- Returns true if the action is currently held (baton OR touch).
--- @param action string
--- @return boolean
function InputPlugin:_is_down(action)
	return self._player:down(action) or self._touch_regions:down(action)
end

--- Returns true if the action was pressed this frame (baton OR touch).
--- @param action string
--- @return boolean
function InputPlugin:_is_pressed(action)
	return self._player:pressed(action) or self._touch_regions:pressed(action)
end

--- Returns true if the action was released this frame (baton OR touch).
--- @param action string
--- @return boolean
function InputPlugin:_is_released(action)
	return self._player:released(action) or self._touch_regions:released(action)
end

--- Called when a joystick is connected. Sets baton joystick and emits event.
--- @param joystick table  Love2D joystick object
function InputPlugin:on_joystick_added(joystick)
	if joystick:isGamepad() and not self._joystick then
		self._joystick = joystick
		self._player.config.joystick = joystick
		self._bus:emit("input:gamepad_connected", {})
	end
end

--- Called when a joystick is disconnected. Clears baton joystick and emits event.
--- @param joystick table  Love2D joystick object
function InputPlugin:on_joystick_removed(joystick)
	if self._joystick == joystick then
		self._joystick = nil
		self._player.config.joystick = nil
		self._bus:emit("input:gamepad_disconnected", {})
	end
end

--- Forward touch press event to touch regions.
--- @param id  any     Touch identifier
--- @param x   number  Screen x
--- @param y   number  Screen y
function InputPlugin:on_touch_pressed(id, x, y)
	self._touch_regions:on_touch_pressed(id, x, y)
end

--- Forward touch release event to touch regions.
--- @param id  any     Touch identifier
--- @param _x  number  Screen x (unused — release ignores position)
--- @param _y  number  Screen y (unused)
function InputPlugin:on_touch_released(id, _x, _y)
	self._touch_regions:on_touch_released(id)
end

--- Shutdown stub — contract established for future use.
--- @param _ctx table  Context (unused)
function InputPlugin:shutdown(_ctx)
	-- No-op: no resources to release for the input plugin.
end

return InputPlugin
