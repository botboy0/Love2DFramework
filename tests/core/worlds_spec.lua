--- Tests for src/core/worlds.lua
--- Dual ECS world factory using tag-based isolation over evolved.lua singleton.
---
--- Run with: busted tests/core/worlds_spec.lua

local Components = require("src.core.components")
local Worlds = require("src.core.worlds")
local evolved = require("lib.evolved")

--- Count entities matching a query (convenience helper).
--- @param q evolved.query The query to execute.
--- @return integer count Number of entities found.
local function count_query(q)
	local n = 0
	for _chunk, _entities, chunk_count in evolved.execute(q) do
		n = n + chunk_count
	end
	return n
end

--- Destroy a list of entities to clean up singleton ECS state.
--- @param entities evolved.entity[] Entities to destroy.
local function destroy_all(entities)
	evolved.defer()
	for _, e in ipairs(entities) do
		if evolved.alive(e) then
			evolved.destroy(e)
		end
	end
	evolved.commit()
end

describe("Worlds", function()
	describe("Worlds.create()", function()
		it("returns a table", function()
			local worlds = Worlds.create()
			assert.is_table(worlds)
		end)

		it("has a server field", function()
			local worlds = Worlds.create()
			assert.is_not_nil(worlds.server)
		end)

		it("has a client field", function()
			local worlds = Worlds.create()
			assert.is_not_nil(worlds.client)
		end)

		it("server and client are different tables", function()
			local worlds = Worlds.create()
			assert.are_not.equal(worlds.server, worlds.client)
		end)

		it("server has a tag fragment", function()
			local worlds = Worlds.create()
			assert.is_not_nil(worlds.server.tag)
			assert.is_number(worlds.server.tag)
		end)

		it("client has a tag fragment", function()
			local worlds = Worlds.create()
			assert.is_not_nil(worlds.client.tag)
			assert.is_number(worlds.client.tag)
		end)

		it("server and client tags are different", function()
			local worlds = Worlds.create()
			assert.are_not.equal(worlds.server.tag, worlds.client.tag)
		end)
	end)

	describe("spawn_server / spawn_client isolation", function()
		local worlds
		local spawned

		before_each(function()
			worlds = Worlds.create()
			spawned = {}
		end)

		after_each(function()
			-- Clean up singleton ECS state between tests
			destroy_all(spawned)
		end)

		it("spawn_server returns a live entity", function()
			local e = worlds:spawn_server({})
			table.insert(spawned, e)
			assert.is_true(evolved.alive(e))
		end)

		it("spawn_client returns a live entity", function()
			local e = worlds:spawn_client({})
			table.insert(spawned, e)
			assert.is_true(evolved.alive(e))
		end)

		it("server entity is not found in client query", function()
			local e = worlds:spawn_server({ [Components.Position] = { x = 10, y = 20 } })
			table.insert(spawned, e)

			-- Query for client-tagged entities with Position — must find zero
			local q = evolved.builder():include(worlds.client.tag, Components.Position):build()
			assert.are.equal(0, count_query(q))
		end)

		it("client entity is not found in server query", function()
			local e = worlds:spawn_client({ [Components.Position] = { x = 30, y = 40 } })
			table.insert(spawned, e)

			-- Query for server-tagged entities with Position — must find zero
			local q = evolved.builder():include(worlds.server.tag, Components.Position):build()
			assert.are.equal(0, count_query(q))
		end)

		it("server entity is found in server query", function()
			local e = worlds:spawn_server({ [Components.Position] = { x = 10, y = 20 } })
			table.insert(spawned, e)

			local q = evolved.builder():include(worlds.server.tag, Components.Position):build()
			assert.is_true(count_query(q) >= 1)
		end)

		it("client entity is found in client query", function()
			local e = worlds:spawn_client({ [Components.Position] = { x = 30, y = 40 } })
			table.insert(spawned, e)

			local q = evolved.builder():include(worlds.client.tag, Components.Position):build()
			assert.is_true(count_query(q) >= 1)
		end)

		it("server and client entities with Position are queryable independently", function()
			local es = worlds:spawn_server({ [Components.Position] = { x = 1, y = 2 } })
			local ec = worlds:spawn_client({ [Components.Position] = { x = 3, y = 4 } })
			table.insert(spawned, es)
			table.insert(spawned, ec)

			local q_server = evolved.builder():include(worlds.server.tag, Components.Position):build()
			local q_client = evolved.builder():include(worlds.client.tag, Components.Position):build()

			assert.is_true(count_query(q_server) >= 1)
			assert.is_true(count_query(q_client) >= 1)
		end)
	end)

	describe("ServerTag and ClientTag constants", function()
		it("Worlds.ServerTag is a number", function()
			assert.is_number(Worlds.ServerTag)
		end)

		it("Worlds.ClientTag is a number", function()
			assert.is_number(Worlds.ClientTag)
		end)

		it("ServerTag and ClientTag are different", function()
			assert.are_not.equal(Worlds.ServerTag, Worlds.ClientTag)
		end)
	end)
end)
