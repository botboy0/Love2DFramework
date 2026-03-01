--- Tests for src/core/worlds.lua
--- Single-world (default) and dual-world (opt-in) ECS factory over evolved.lua singleton.
---
--- Run with: busted tests/core/worlds_spec.lua

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
	describe("single-world mode", function()
		local worlds
		local spawned

		before_each(function()
			worlds = Worlds.create()
			spawned = {}
		end)

		after_each(function()
			destroy_all(spawned)
		end)

		it("Worlds.create() returns a table", function()
			assert.is_table(worlds)
		end)

		it("server field is nil in single-world mode", function()
			assert.is_nil(worlds.server)
		end)

		it("client field is nil in single-world mode", function()
			assert.is_nil(worlds.client)
		end)

		it("worlds:spawn() returns a live entity", function()
			local e = worlds:spawn({})
			table.insert(spawned, e)
			assert.is_true(evolved.alive(e))
		end)

		it("worlds:spawn() with no args returns a live entity", function()
			local e = worlds:spawn()
			table.insert(spawned, e)
			assert.is_true(evolved.alive(e))
		end)

		it("worlds:spawn_server() errors with 'single-world' in message", function()
			assert.has_error(function()
				worlds:spawn_server()
			end, nil)
			-- Verify message contains "single-world"
			local ok, err = pcall(function()
				worlds:spawn_server()
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("single%-world"))
		end)

		it("worlds:spawn_client() errors with 'single-world' in message", function()
			local ok, err = pcall(function()
				worlds:spawn_client()
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("single%-world"))
		end)
	end)

	describe("dual-world mode", function()
		local worlds
		local spawned
		-- Allocate a Position-like fragment for isolation queries in dual-world tests
		local TestFragment = evolved.id(1)

		before_each(function()
			worlds = Worlds.create({ dual = true })
			spawned = {}
		end)

		after_each(function()
			destroy_all(spawned)
		end)

		it("Worlds.create({ dual = true }) returns a table", function()
			assert.is_table(worlds)
		end)

		it("has a server field", function()
			assert.is_not_nil(worlds.server)
		end)

		it("has a client field", function()
			assert.is_not_nil(worlds.client)
		end)

		it("server and client are different tables", function()
			assert.are_not.equal(worlds.server, worlds.client)
		end)

		it("server has a tag fragment", function()
			assert.is_not_nil(worlds.server.tag)
			assert.is_number(worlds.server.tag)
		end)

		it("client has a tag fragment", function()
			assert.is_not_nil(worlds.client.tag)
			assert.is_number(worlds.client.tag)
		end)

		it("server and client tags are different", function()
			assert.are_not.equal(worlds.server.tag, worlds.client.tag)
		end)

		it("worlds.server.tag == Worlds.ServerTag", function()
			assert.are.equal(Worlds.ServerTag, worlds.server.tag)
		end)

		it("worlds.client.tag == Worlds.ClientTag", function()
			assert.are.equal(Worlds.ClientTag, worlds.client.tag)
		end)

		it("spawn_server() returns a live entity", function()
			local e = worlds:spawn_server({})
			table.insert(spawned, e)
			assert.is_true(evolved.alive(e))
		end)

		it("spawn_client() returns a live entity", function()
			local e = worlds:spawn_client({})
			table.insert(spawned, e)
			assert.is_true(evolved.alive(e))
		end)

		it("server entity is not found in client query", function()
			local e = worlds:spawn_server({ [TestFragment] = true })
			table.insert(spawned, e)

			local q = evolved.builder():include(worlds.client.tag, TestFragment):build()
			assert.are.equal(0, count_query(q))
		end)

		it("client entity is not found in server query", function()
			local e = worlds:spawn_client({ [TestFragment] = true })
			table.insert(spawned, e)

			local q = evolved.builder():include(worlds.server.tag, TestFragment):build()
			assert.are.equal(0, count_query(q))
		end)

		it("server entity is found in server query", function()
			local e = worlds:spawn_server({ [TestFragment] = true })
			table.insert(spawned, e)

			local q = evolved.builder():include(worlds.server.tag, TestFragment):build()
			assert.is_true(count_query(q) >= 1)
		end)

		it("client entity is found in client query", function()
			local e = worlds:spawn_client({ [TestFragment] = true })
			table.insert(spawned, e)

			local q = evolved.builder():include(worlds.client.tag, TestFragment):build()
			assert.is_true(count_query(q) >= 1)
		end)

		it("server and client entities are queryable independently", function()
			local es = worlds:spawn_server({ [TestFragment] = true })
			local ec = worlds:spawn_client({ [TestFragment] = true })
			table.insert(spawned, es)
			table.insert(spawned, ec)

			local q_server = evolved.builder():include(worlds.server.tag, TestFragment):build()
			local q_client = evolved.builder():include(worlds.client.tag, TestFragment):build()

			assert.is_true(count_query(q_server) >= 1)
			assert.is_true(count_query(q_client) >= 1)
		end)

		it("worlds:spawn() errors with 'dual-world' in message", function()
			local ok, err = pcall(function()
				worlds:spawn()
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("dual%-world"))
		end)

		it("worlds:spawn() error hints to use spawn_server or spawn_client", function()
			local ok, err = pcall(function()
				worlds:spawn()
			end)
			assert.is_false(ok)
			assert.is_truthy(err:find("spawn_server") or err:find("spawn_client"))
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
