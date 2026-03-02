--- Explicit plugin boot manifest.
---
--- This is the single authoritative list of plugins to load at startup.
--- Each entry: { name = "plugin_name", module = require("src.plugins.x"), deps = { ... } }
---
--- No auto-discovery — this list IS the boot manifest.
--- Add entries here when new plugins are ready.
---
--- Loaded by main.lua and passed to the plugin registry:
---   local list = require("src.core.plugin_list")
---   for _, entry in ipairs(list) do
---     registry:register(entry.name, entry.module, { deps = entry.deps })
---   end

return {
	{
		name = "input",
		module = "src.plugins.input",
		deps = {},
	},
	{
		name = "assets",
		module = "src.plugins.assets",
		deps = {},
	},
}
