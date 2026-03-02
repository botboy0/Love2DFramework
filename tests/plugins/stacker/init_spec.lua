--- Tests for src/plugins/stacker/init.lua
--- Exercises stacker game logic: spawn counts, movement, placement, game-over.
--- Uses plugin_harness for isolated context. ECS entities are purged between tests
--- via evolved.collect() which destroys all entities.

local C = require("src.core.components")
local StackerPlugin = require("src.plugins.stacker")
local evolved = require("lib.evolved")
local harness = require("tests.helpers.plugin_harness")

--- Count all entities matching a query.
--- @param q table  evolved query
--- @return number
local function count_query(q)
	local n = 0
	for _chunk, _entities, count in evolved.execute(q) do
		n = n + count
	end
	return n
end

--- Return the first component value matching a query, or nil.
--- @param q table  evolved query
--- @param frag any  fragment ID
--- @return table|nil
local function first_component(q, frag)
	for chunk, _entities, count in evolved.execute(q) do
		local comps = chunk:components(frag)
		if count > 0 then
			return comps[1]
		end
	end
	return nil
end

--- Destroy all entities in the ECS world between tests.
local function purge_all_entities()
	local all_q = evolved.builder():build()
	evolved.defer()
	for _chunk, entities, count in evolved.execute(all_q) do
		for i = 1, count do
			evolved.destroy(entities[i])
		end
	end
	evolved.commit()
end

--- A minimal stacker plugin instance (fresh table, not the module singleton).
--- We must create a fresh copy per test because init() writes to self._bus etc.
local function make_plugin()
	return setmetatable({}, StackerPlugin)
end

describe("StackerPlugin", function()
	local ctx
	local moving_q
	local stack_q
	local state_q

	before_each(function()
		ctx = harness.create_context({
			config = { input = { place = { key = "space", sc = "space" } } },
		})
		moving_q = evolved.builder():include(C.MovingBlock):build()
		stack_q = evolved.builder():include(C.StackBlock):build()
		state_q = evolved.builder():include(C.GameState):build()
	end)

	after_each(function()
		purge_all_entities()
		harness.teardown(ctx)
	end)

	describe("init()", function()
		it("spawns exactly 1 GameState entity", function()
			local plugin = make_plugin()
			plugin:init(ctx)
			assert.are.equal(1, count_query(state_q))
		end)

		it("spawns exactly 1 StackBlock (floor)", function()
			local plugin = make_plugin()
			plugin:init(ctx)
			assert.are.equal(1, count_query(stack_q))
		end)

		it("spawns exactly 1 MovingBlock", function()
			local plugin = make_plugin()
			plugin:init(ctx)
			assert.are.equal(1, count_query(moving_q))
		end)

		it("initializes GameState with score=0 and active=true", function()
			local plugin = make_plugin()
			plugin:init(ctx)
			local gs = first_component(state_q, C.GameState)
			assert.is_not_nil(gs)
			assert.are.equal(0, gs.score)
			assert.is_true(gs.active)
		end)
	end)

	describe("update(dt)", function()
		it("moves moving block x by speed * dir * dt", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			local mb = first_component(moving_q, C.MovingBlock)
			assert.is_not_nil(mb)
			local initial_x = mb.x
			local dir = mb.dir
			local speed = mb.speed

			plugin:update(0.016)

			-- re-fetch after update
			mb = first_component(moving_q, C.MovingBlock)
			local expected_x = initial_x + speed * dir * 0.016
			assert.are.equal(expected_x, mb.x)
		end)

		it("reverses dir when block reaches right edge (x + w >= SCREEN_W)", function()
			local SCREEN_W = 1280
			local plugin = make_plugin()
			plugin:init(ctx)

			-- Force moving block to near right edge
			for chunk, _entities, count in evolved.execute(moving_q) do
				local blocks = chunk:components(C.MovingBlock)
				for i = 1, count do
					blocks[i].x = SCREEN_W - blocks[i].w -- exactly at right edge
					blocks[i].dir = 1 -- moving right
				end
			end

			plugin:update(0.016)

			local mb = first_component(moving_q, C.MovingBlock)
			assert.are.equal(-1, mb.dir)
		end)

		it("does NOT move block when game is inactive", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			-- Deactivate game
			for chunk, _entities, count in evolved.execute(state_q) do
				local states = chunk:components(C.GameState)
				for i = 1, count do
					states[i].active = false
				end
			end

			local mb_before = first_component(moving_q, C.MovingBlock)
			local x_before = mb_before.x

			plugin:update(0.1)

			local mb_after = first_component(moving_q, C.MovingBlock)
			assert.are.equal(x_before, mb_after.x)
		end)
	end)

	describe("placement via input:action_pressed", function()
		it("trims moving block to overlap width on partial overlap", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			-- Position moving block to partial overlap (shifted right by 50px)
			local gs = first_component(state_q, C.GameState)
			for chunk, _entities, count in evolved.execute(moving_q) do
				local blocks = chunk:components(C.MovingBlock)
				for i = 1, count do
					-- shift right 50px — overlap is (START_W - 50) = 250
					blocks[i].x = gs.tower_top_x + 50
				end
			end

			-- Call _try_place directly (avoids bus re-entrancy issues with flush)
			plugin:_try_place()

			local mb = first_component(moving_q, C.MovingBlock)
			-- The overlap region is tower_top_w (300) - 50 = 250
			assert.are.equal(250, mb.w)
		end)

		it("increments score by 1 on successful placement", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			-- Call _try_place directly
			plugin:_try_place()

			local gs = first_component(state_q, C.GameState)
			assert.are.equal(1, gs.score)
		end)

		it("emits stacker:game_over when overlap is zero", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			-- Subscribe before emitting the action so the handler is registered
			local game_over_fired = false
			local game_over_score = nil
			ctx.bus:on("stacker:game_over", function(data)
				game_over_fired = true
				game_over_score = data.score
			end)

			-- Move block completely off tower (no overlap)
			-- Floor is at x=(1280-300)/2=490; put block at far left with narrow width
			for chunk, _entities, count in evolved.execute(moving_q) do
				local blocks = chunk:components(C.MovingBlock)
				for i = 1, count do
					blocks[i].x = 0
					blocks[i].w = 10
				end
			end

			-- Emit input — _try_place runs during flush and calls bus:emit("stacker:game_over")
			-- which is re-entrant (discarded). Emit directly instead to test the event path.
			-- The real-game path: main.lua calls bus:flush() then bus:flush() each tick,
			-- so game_over is queued in update phase and delivered next flush.
			-- For the spec we call _try_place directly and then emit the event manually to
			-- verify that gs.active=false (state test) and that the event fires correctly.
			-- The stacker:game_over bus test is covered via direct emit below.
			plugin:_try_place()

			-- After _try_place the game_over event is queued (re-entrant emit is discarded
			-- by the bus guard during flush, but direct _try_place is NOT during a flush)
			ctx.bus:flush()

			assert.is_true(game_over_fired)
			assert.are.equal(0, game_over_score)
		end)

		it("sets gs.active = false when overlap is zero", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			-- Move block completely off tower
			for chunk, _entities, count in evolved.execute(moving_q) do
				local blocks = chunk:components(C.MovingBlock)
				for i = 1, count do
					blocks[i].x = 0
					blocks[i].w = 10
				end
			end

			-- Call _try_place directly to avoid bus re-entrancy guard during flush
			plugin:_try_place()

			local gs = first_component(state_q, C.GameState)
			assert.is_false(gs.active)
		end)
	end)
end)
