--- ECS world factory with single-world (default) and dual-world (opt-in) modes.
---
--- evolved.lua is a global singleton ECS — it does not support multiple "world"
--- instances via constructor. Dual-world separation is achieved through namespace
--- isolation: entities are tagged with ServerTag or ClientTag fragments. Queries
--- for server systems include ServerTag; client systems include ClientTag.
---
--- Single-world mode (default):
---   local worlds = Worlds.create()
---   local entity = worlds:spawn({ [MyComponent] = value })
---
--- Dual-world mode (opt-in):
---   local worlds = Worlds.create({ dual = true })
---   local entity = worlds:spawn_server({ [Components.Position] = { x = 0, y = 0 } })

local evolved = require("lib.evolved")

local Worlds = {}

--- Tag fragments that identify which "world" an entity belongs to.
--- These are module-level constants so all Worlds.create() instances share them.
Worlds.ServerTag, Worlds.ClientTag = evolved.id(2)

--- Create a worlds object.
--- @param opts table|nil Options table. Pass { dual = true } for dual-world mode.
--- @return table worlds The world handle with spawn helpers appropriate to the mode.
function Worlds.create(opts)
	local dual = opts and opts.dual == true

	if dual then
		-- Dual-world mode: entities are tagged with ServerTag or ClientTag.
		local server_tag = Worlds.ServerTag
		local client_tag = Worlds.ClientTag

		local worlds = {
			server = { tag = server_tag },
			client = { tag = client_tag },
		}

		--- Spawn is ambiguous in dual-world mode — use spawn_server or spawn_client.
		function worlds:spawn(_components)
			error("spawn() is ambiguous in dual-world mode — use spawn_server() or spawn_client()")
		end

		--- Spawn an entity in the server world.
		--- @param components table Component table (fragment -> value). ServerTag is added automatically.
		--- @return evolved.entity The spawned entity ID.
		function worlds:spawn_server(components)
			local comps = components or {}
			comps[server_tag] = true
			return evolved.spawn(comps)
		end

		--- Spawn an entity in the client world.
		--- @param components table Component table (fragment -> value). ClientTag is added automatically.
		--- @return evolved.entity The spawned entity ID.
		function worlds:spawn_client(components)
			local comps = components or {}
			comps[client_tag] = true
			return evolved.spawn(comps)
		end

		return worlds
	else
		-- Single-world mode (default): no tag isolation, spawn() calls evolved.spawn() directly.
		local worlds = {}

		--- Spawn an entity in the single ECS world with no tag added.
		--- @param components table|nil Component table (fragment -> value).
		--- @return evolved.entity The spawned entity ID.
		function worlds:spawn(components)
			return evolved.spawn(components or {})
		end

		--- Not available in single-world mode.
		function worlds:spawn_server(_components)
			error("spawn_server() is not available in single-world mode — use worlds:spawn() instead")
		end

		--- Not available in single-world mode.
		function worlds:spawn_client(_components)
			error("spawn_client() is not available in single-world mode — use worlds:spawn() instead")
		end

		return worlds
	end
end

return Worlds
