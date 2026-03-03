--- Tests for src/plugins/stacker/init.lua
--- Exercises stacker game logic: spawn counts, movement, placement, game-over.
--- Uses plugin_harness for isolated context. ECS entities are purged between tests
--- via evolved.collect() which destroys all entities.

local C = require("src.core.components")
local StackerPlugin = require("src.plugins.stacker")
local evolved = require("lib.evolved")
local harness = require("tests.helpers.plugin_harness")

--- Mock love.graphics so stacker init() can call getWidth/getHeight headlessly.
--- Use _G explicitly so the mock reaches the global scope that src/ code reads.
if not _G.love then
	_G.love = {}
end
if not _G.love.graphics then
	_G.love.graphics = {}
end
_G.love.graphics.getWidth = _G.love.graphics.getWidth or function()
	return 720
end
_G.love.graphics.getHeight = _G.love.graphics.getHeight or function()
	return 1280
end

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
		moving_q = evolved.builder():include(C.MovingRow):build()
		stack_q = evolved.builder():include(C.StackRow):build()
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

		it("spawns exactly 1 StackRow (floor)", function()
			local plugin = make_plugin()
			plugin:init(ctx)
			assert.are.equal(1, count_query(stack_q))
		end)

		it("spawns exactly 1 MovingRow", function()
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
		it("moves moving row col by dir when timer exceeds speed", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			local mr = first_component(moving_q, C.MovingRow)
			assert.is_not_nil(mr)
			local initial_col = mr.col
			local dir = mr.dir

			-- Advance by enough time to trigger at least one move
			plugin:update(mr.speed + 0.001)

			mr = first_component(moving_q, C.MovingRow)
			assert.are.equal(initial_col + dir, mr.col)
		end)

		it("reverses dir when block reaches right edge (col + width > GRID_COLS)", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			-- Force moving row to right edge
			for chunk, _entities, count in evolved.execute(moving_q) do
				local rows = chunk:components(C.MovingRow)
				for i = 1, count do
					rows[i].col = 7 - rows[i].width -- at right edge (GRID_COLS=7)
					rows[i].dir = 1
					rows[i].timer = 0
				end
			end

			-- Advance enough to trigger a move
			local mr = first_component(moving_q, C.MovingRow)
			plugin:update(mr.speed + 0.001)

			mr = first_component(moving_q, C.MovingRow)
			assert.are.equal(-1, mr.dir)
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

			local mr_before = first_component(moving_q, C.MovingRow)
			local col_before = mr_before.col

			plugin:update(1.0)

			local mr_after = first_component(moving_q, C.MovingRow)
			assert.are.equal(col_before, mr_after.col)
		end)
	end)

	describe("placement via input:action_pressed", function()
		it("trims moving row to overlap width on partial overlap", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			-- Position moving row to partial overlap (shifted right by 2 cells)
			local gs = first_component(state_q, C.GameState)
			local original_width = gs.top_width -- 4
			for chunk, _entities, count in evolved.execute(moving_q) do
				local rows = chunk:components(C.MovingRow)
				for i = 1, count do
					rows[i].col = gs.top_col + 2
				end
			end

			plugin:_try_place()

			-- Overlap = original_width - 2 = 2
			local mr = first_component(moving_q, C.MovingRow)
			assert.are.equal(original_width - 2, mr.width)
		end)

		it("increments score by 1 on successful placement", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			plugin:_try_place()

			local gs = first_component(state_q, C.GameState)
			assert.are.equal(1, gs.score)
		end)

		it("emits stacker:game_over when overlap is zero", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			local game_over_fired = false
			local game_over_score = nil
			ctx.bus:on("stacker:game_over", function(data)
				game_over_fired = true
				game_over_score = data.score
			end)

			-- Move block completely off tower (no overlap)
			for chunk, _entities, count in evolved.execute(moving_q) do
				local rows = chunk:components(C.MovingRow)
				for i = 1, count do
					rows[i].col = 0
					rows[i].width = 1
				end
			end

			-- Force tower to far right so there's no overlap
			local gs = first_component(state_q, C.GameState)
			for chunk, _entities, count in evolved.execute(moving_q) do
				local rows = chunk:components(C.MovingRow)
				for i = 1, count do
					rows[i].col = gs.top_col + gs.top_width + 1
				end
			end

			plugin:_try_place()
			ctx.bus:flush()

			assert.is_true(game_over_fired)
			assert.are.equal(0, game_over_score)
		end)

		it("sets gs.active = false when overlap is zero", function()
			local plugin = make_plugin()
			plugin:init(ctx)

			-- Move block completely off tower
			local gs = first_component(state_q, C.GameState)
			for chunk, _entities, count in evolved.execute(moving_q) do
				local rows = chunk:components(C.MovingRow)
				for i = 1, count do
					rows[i].col = gs.top_col + gs.top_width + 1
					rows[i].width = 1
				end
			end

			plugin:_try_place()

			gs = first_component(state_q, C.GameState)
			assert.is_false(gs.active)
		end)
	end)
end)
