local Bus = require("src.core.bus")
local Context = require("src.core.context")
local Registry = require("src.core.registry")
local Worlds = require("src.core.worlds")
local plugin_list = require("src.core.plugin_list")

--- Game-specific configuration.
--- Override these values here or in conf.lua to customize behavior.
--- transport: nil (default, no networking) | Transport instance (real networking)
local _config = {
	-- error_mode = "tolerant",  -- global error mode for all modules
	-- error_modes = { bus = "strict", registry = "tolerant" },  -- per-module overrides
	-- transport = nil,  -- set to a Transport instance to enable networking
	input = {
		place = { key = "space", sc = "space" },
	},
}

local _registry
local _ctx
local _input_plugin

function love.load()
	-- Resolve bus error mode from config
	local bus_error_mode = (_config.error_modes and _config.error_modes.bus) or _config.error_mode or "tolerant"

	local bus = Bus.new({ error_mode = bus_error_mode, log = print })
	local worlds = Worlds.create()

	-- Thread config and transport option through to Context.new.
	-- transport = nil/false → NullTransport (default, no networking)
	-- transport = instance  → use it, install auto-bridge
	_ctx = Context.new({
		worlds = worlds,
		bus = bus,
		config = _config,
		transport = _config.transport,
	})

	_registry = Registry.new({ config = _config, log = print })

	-- Register plugins from the explicit plugin list
	for _, entry in ipairs(plugin_list) do
		local plugin_module = require(entry.module)
		_registry:register(entry.name, plugin_module, { deps = entry.deps or {} })
	end

	-- Boot all plugins in topological dependency order
	_registry:boot(_ctx)

	-- Store a reference to the input plugin for callback forwarding
	_input_plugin = require("src.plugins.input")
end

function love.update(_dt)
	if not _ctx then
		return
	end
	-- 1. Update all plugins (e.g. input polling, per-frame logic)
	--    Runs before bus:flush so events emitted by plugins are delivered this tick
	_registry:update_all(_dt)
	-- 2. Receive inbound transport messages and queue as bus events
	--    (inbound messages are queued before flush so they are delivered this tick)
	local messages = _ctx.transport:receive_all()
	for _, msg in ipairs(messages) do
		_ctx.bus:emit(msg.event, msg.data)
	end
	-- 3. Flush bus — delivers all queued events including inbound transport messages
	_ctx.bus:flush()
	-- 4. Flush transport — sends outbound networkable events queued by the auto-bridge
	_ctx.transport:flush()
end

function love.draw()
	if not _registry then
		return
	end
	_registry:draw_all()
end

function love.quit()
	if _registry and _ctx then
		_registry:shutdown(_ctx)
	end
end

function love.joystickadded(joystick)
	if _input_plugin and _input_plugin.on_joystick_added then
		_input_plugin:on_joystick_added(joystick)
	end
end

function love.joystickremoved(joystick)
	if _input_plugin and _input_plugin.on_joystick_removed then
		_input_plugin:on_joystick_removed(joystick)
	end
end

function love.touchpressed(id, x, y, _dx, _dy, _pressure)
	if _input_plugin and _input_plugin.on_touch_pressed then
		_input_plugin:on_touch_pressed(id, x, y)
	end
end

function love.touchreleased(id, x, y, _dx, _dy, _pressure)
	if _input_plugin and _input_plugin.on_touch_released then
		_input_plugin:on_touch_released(id, x, y)
	end
end
