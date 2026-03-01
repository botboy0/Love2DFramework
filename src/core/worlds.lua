--- Dual ECS world factory using tag-based isolation.
---
--- evolved.lua is a global singleton ECS — it does not support multiple "world"
--- instances via constructor. Dual-world separation is achieved through namespace
--- isolation: entities are tagged with ServerTag or ClientTag fragments. Queries
--- for server systems include ServerTag; client systems include ClientTag.
---
--- Usage:
---   local Worlds = require("src.core.worlds")
---   local worlds = Worlds.create()
---   local entity = worlds:spawn_server({ [Components.Position] = { x = 0, y = 0 } })

local evolved = require("lib.evolved")

local Worlds = {}

--- Tag fragments that identify which "world" an entity belongs to.
--- These are module-level constants so all Worlds.create() instances share them.
Worlds.ServerTag, Worlds.ClientTag = evolved.id(2)

--- Create a worlds object with server and client namespaces.
--- @return table worlds The dual-world handle with spawn helpers.
function Worlds.create()
	local server_tag = Worlds.ServerTag
	local client_tag = Worlds.ClientTag

	local worlds = {
		server = { tag = server_tag },
		client = { tag = client_tag },
	}

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
end

return Worlds
