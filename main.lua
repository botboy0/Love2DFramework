local Bus = require("src.core.bus")
local Context = require("src.core.context")
local Registry = require("src.core.registry")
local Worlds = require("src.core.worlds")
local plugin_list = require("src.core.plugin_list")

local _registry
local _ctx

function love.load()
	local bus = Bus.new()
	local worlds = Worlds.create()
	_ctx = Context.new({ worlds = worlds, bus = bus })

	_registry = Registry.new()

	-- Register plugins from the explicit plugin list
	for _, entry in ipairs(plugin_list) do
		local plugin_module = require(entry.module)
		_registry:register(entry.name, plugin_module, { deps = entry.deps or {} })
	end

	-- Boot all plugins in topological dependency order
	_registry:boot(_ctx)
end

function love.update(_dt)
	-- Flush event bus at end of tick
	if _ctx then
		_ctx.bus:flush()
	end
end

function love.draw()
	-- Future: call registered render systems
end
