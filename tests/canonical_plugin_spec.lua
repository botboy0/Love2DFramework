--- Tests for examples/canonical_plugin.lua
--- Verifies the canonical plugin lifecycle using the upgraded plugin harness.
---
--- Run with: busted tests/canonical_plugin_spec.lua

local Bus = require("src.core.bus")
local CanonicalPlugin = require("examples.canonical_plugin")
local Context = require("src.core.context")
local Worlds = require("src.core.worlds")
local evolved = require("lib.evolved")
local harness = require("tests.helpers.plugin_harness")

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

--- Create a single-world context for single-world mode tests.
--- ctx.worlds.server will be nil in this mode.
local function create_single_world_ctx()
	local bus = Bus.new()
	local worlds = Worlds.create() -- single-world, no dual=true
	local ctx = Context.new({ worlds = worlds, bus = bus, config = {} })
	return ctx
end

describe("CanonicalPlugin", function()
	local ctx
	local spawned

	before_each(function()
		ctx = harness.create_context()
		spawned = {}
		-- Fresh plugin instance per test to avoid shared self state
		CanonicalPlugin._last_spawned = nil
		CanonicalPlugin._movement_query = nil
		CanonicalPlugin.bus = nil
		CanonicalPlugin.worlds = nil
	end)

	after_each(function()
		destroy_all(spawned)
	end)

	describe("init", function()
		it("succeeds without error", function()
			assert.has_no_error(function()
				CanonicalPlugin:init(ctx)
			end)
		end)

		it("stores bus reference on self", function()
			CanonicalPlugin:init(ctx)
			assert.are.equal(ctx.bus, CanonicalPlugin.bus)
		end)

		it("stores worlds reference on self", function()
			CanonicalPlugin:init(ctx)
			assert.are.equal(ctx.worlds, CanonicalPlugin.worlds)
		end)

		it("registers canonical_query service", function()
			CanonicalPlugin:init(ctx)
			local svc = ctx.services:get("canonical_query")
			assert.is_not_nil(svc)
		end)

		it("canonical_query service exposes get_movement_query", function()
			CanonicalPlugin:init(ctx)
			local svc = ctx.services:get("canonical_query")
			assert.is_function(svc.get_movement_query)
		end)

		it("get_movement_query returns the built query", function()
			CanonicalPlugin:init(ctx)
			local svc = ctx.services:get("canonical_query")
			local q = svc.get_movement_query()
			assert.is_not_nil(q)
		end)

		it("succeeds in single-world mode (ctx.worlds.server is nil)", function()
			local single_ctx = create_single_world_ctx()
			CanonicalPlugin._last_spawned = nil
			CanonicalPlugin._movement_query = nil
			CanonicalPlugin.bus = nil
			CanonicalPlugin.worlds = nil
			assert.has_no_error(function()
				CanonicalPlugin:init(single_ctx)
			end)
		end)
	end)

	describe("update", function()
		it("moves entities with Position and Velocity components", function()
			CanonicalPlugin:init(ctx)

			-- Spawn a server entity using the plugin's own fragment IDs
			local e = ctx.worlds:spawn_server({
				[CanonicalPlugin.Position] = { x = 10.0, y = 20.0 },
				[CanonicalPlugin.Velocity] = { dx = 5.0, dy = -3.0 },
			})
			table.insert(spawned, e)

			-- Run one update tick (dt = 1.0 for easy arithmetic)
			CanonicalPlugin:update(1.0)

			-- Verify position was updated
			local pos = evolved.get(e, CanonicalPlugin.Position)
			assert.is_not_nil(pos)
			assert.are.equal(15.0, pos.x)
			assert.are.equal(17.0, pos.y)
		end)

		it("does not affect entities without Velocity", function()
			CanonicalPlugin:init(ctx)

			-- Spawn a server entity with only Position (no Velocity)
			local e = ctx.worlds:spawn_server({
				[CanonicalPlugin.Position] = { x = 5.0, y = 5.0 },
			})
			table.insert(spawned, e)

			-- Update should not touch this entity
			CanonicalPlugin:update(1.0)

			local pos = evolved.get(e, CanonicalPlugin.Position)
			assert.are.equal(5.0, pos.x)
			assert.are.equal(5.0, pos.y)
		end)

		it("uses delta time correctly (dt = 0.5)", function()
			CanonicalPlugin:init(ctx)

			local e = ctx.worlds:spawn_server({
				[CanonicalPlugin.Position] = { x = 0.0, y = 0.0 },
				[CanonicalPlugin.Velocity] = { dx = 10.0, dy = 4.0 },
			})
			table.insert(spawned, e)

			CanonicalPlugin:update(0.5)

			local pos = evolved.get(e, CanonicalPlugin.Position)
			assert.are.equal(5.0, pos.x)
			assert.are.equal(2.0, pos.y)
		end)

		it("updates entities in single-world mode without error", function()
			local single_ctx = create_single_world_ctx()
			CanonicalPlugin._last_spawned = nil
			CanonicalPlugin._movement_query = nil
			CanonicalPlugin.bus = nil
			CanonicalPlugin.worlds = nil
			CanonicalPlugin:init(single_ctx)

			-- In single-world mode, spawn via worlds:spawn() (no server tag)
			local e = single_ctx.worlds:spawn({
				[CanonicalPlugin.Position] = { x = 1.0, y = 2.0 },
				[CanonicalPlugin.Velocity] = { dx = 3.0, dy = 4.0 },
			})
			table.insert(spawned, e)

			assert.has_no_error(function()
				CanonicalPlugin:update(1.0)
			end)

			local pos = evolved.get(e, CanonicalPlugin.Position)
			assert.are.equal(4.0, pos.x)
			assert.are.equal(6.0, pos.y)
		end)
	end)

	describe("event handling", function()
		it("records last spawned entity from entity_spawned event", function()
			CanonicalPlugin:init(ctx)

			-- Emit entity_spawned event
			ctx.bus:emit("entity_spawned", { entity = 42 })
			ctx.bus:flush()

			assert.are.equal(42, CanonicalPlugin._last_spawned)
		end)

		it("updates last_spawned when event fires multiple times", function()
			CanonicalPlugin:init(ctx)

			ctx.bus:emit("entity_spawned", { entity = 1 })
			ctx.bus:flush()
			ctx.bus:emit("entity_spawned", { entity = 2 })
			ctx.bus:flush()

			assert.are.equal(2, CanonicalPlugin._last_spawned)
		end)
	end)

	describe("shutdown", function()
		it("is callable without error", function()
			CanonicalPlugin:init(ctx)
			assert.has_no_error(function()
				CanonicalPlugin:shutdown(ctx)
			end)
		end)

		it("is callable before init without error", function()
			assert.has_no_error(function()
				CanonicalPlugin:shutdown(ctx)
			end)
		end)
	end)
end)
