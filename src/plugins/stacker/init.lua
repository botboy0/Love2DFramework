--- Stacker game plugin.
--- Classic arcade stacker: a block oscillates left/right, player presses 'place'
--- to stack it. Only the overlapping portion with the block below is kept.
--- Blocks narrow on imperfect placements. Game over when width reaches zero.
---
--- Depends on: "input" service (via bus events — no direct service calls).
--- Emits:  stacker:placed   { score, block_w }
---         stacker:game_over { score }
---         stacker:reset    {}
---
--- Follow canonical_plugin.lua pattern exactly.
--- See CLAUDE.md for architectural rules.

local C = require("src.core.components")
local evolved = require("lib.evolved")

local StackerPlugin = {}
StackerPlugin.__index = StackerPlugin

StackerPlugin.name = "stacker"
StackerPlugin.deps = {} -- uses bus events from input, not direct service dep

--- Game constants
local SCREEN_W = 1280
local SCREEN_H = 720
local BLOCK_H = 30 -- height of each layer
local START_W = 300 -- width of first block
local SPEED_BASE = 250 -- px/s initial oscillation speed
local SPEED_INC = 20 -- px/s speed increase per successful placement
local FLOOR_Y = SCREEN_H - 60 -- y position of the bottom layer
local COLORS = {
	{ 0.96, 0.26, 0.21 },
	{ 0.13, 0.59, 0.95 },
	{ 0.30, 0.69, 0.31 },
	{ 1.00, 0.76, 0.03 },
	{ 0.61, 0.15, 0.69 },
	{ 0.00, 0.74, 0.83 },
}

--- Initialize the plugin.
--- Spawns the initial GameState and first StackBlock (the floor), then the first MovingBlock.
--- @param ctx table { worlds, bus, config, services, transport }
function StackerPlugin:init(ctx)
	self._bus = ctx.bus
	self._worlds = ctx.worlds

	-- Queries built at init, reused every frame
	self._moving_query = evolved.builder():include(C.MovingBlock):build()
	self._stack_query = evolved.builder():include(C.StackBlock):build()
	self._state_query = evolved.builder():include(C.GameState):build()

	-- Spawn singleton GameState
	evolved.spawn({
		[C.GameState] = {
			score = 0,
			active = true,
			tower_top_x = (SCREEN_W - START_W) / 2,
			tower_top_w = START_W,
		},
	})

	-- Spawn the floor block (layer 0)
	evolved.spawn({
		[C.StackBlock] = {
			x = (SCREEN_W - START_W) / 2,
			y = FLOOR_Y,
			w = START_W,
			h = BLOCK_H,
			color = COLORS[1],
		},
	})

	-- Spawn the first moving block one layer above the floor
	evolved.spawn({
		[C.MovingBlock] = {
			x = (SCREEN_W - START_W) / 2,
			y = FLOOR_Y - BLOCK_H,
			w = START_W,
			h = BLOCK_H,
			speed = SPEED_BASE,
			dir = 1,
		},
	})

	-- Listen for 'place' action via bus (input plugin emits this)
	ctx.bus:on("input:action_pressed", function(data)
		if data.action == "place" then
			self:_try_place()
		end
	end)
end

--- Per-frame update: move the oscillating block left/right.
--- @param dt number  Delta time in seconds
function StackerPlugin:update(dt)
	for chunk, _entities, count in evolved.execute(self._moving_query) do
		local blocks = chunk:components(C.MovingBlock)
		for i = 1, count do
			local b = blocks[i]
			-- Only move when game is active
			if self:_is_active() then
				b.x = b.x + b.speed * b.dir * dt
				-- Bounce off screen edges (keep block fully visible)
				if b.x < 0 then
					b.x = 0
					b.dir = 1
				elseif b.x + b.w > SCREEN_W then
					b.x = SCREEN_W - b.w
					b.dir = -1
				end
			end
		end
	end
end

--- Draw all stacked blocks and the moving block.
function StackerPlugin:draw()
	-- Draw placed stack
	for chunk, _entities, count in evolved.execute(self._stack_query) do
		local blocks = chunk:components(C.StackBlock)
		for i = 1, count do
			local b = blocks[i]
			love.graphics.setColor(b.color[1], b.color[2], b.color[3])
			love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
		end
	end

	-- Draw moving block (bright white outline + semi-transparent fill)
	for chunk, _entities, count in evolved.execute(self._moving_query) do
		local blocks = chunk:components(C.MovingBlock)
		for i = 1, count do
			local b = blocks[i]
			love.graphics.setColor(1, 1, 1, 0.85)
			love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
			love.graphics.setColor(0, 0, 0)
			love.graphics.rectangle("line", b.x, b.y, b.w, b.h)
		end
	end

	-- Draw score (top-left)
	love.graphics.setColor(1, 1, 1)
	for chunk, _entities, count in evolved.execute(self._state_query) do
		local states = chunk:components(C.GameState)
		for i = 1, count do
			local s = states[i]
			love.graphics.print("Score: " .. tostring(s.score), 10, 10)
			if not s.active then
				love.graphics.print("GAME OVER — press R to restart", SCREEN_W / 2 - 150, SCREEN_H / 2)
			end
		end
	end
end

--- Attempt to place the moving block on the tower.
--- Computes overlap with the top of the stack. If overlap > 0, spawns a new
--- StackBlock for the overlapping region and repositions the moving block.
--- If overlap == 0, emits game_over. Structural ECS mutations use defer/commit.
function StackerPlugin:_try_place()
	-- Read current moving block
	local mb_x, mb_w, mb_y, mb_speed
	for chunk, _entities, count in evolved.execute(self._moving_query) do
		local blocks = chunk:components(C.MovingBlock)
		for i = 1, count do
			mb_x = blocks[i].x
			mb_w = blocks[i].w
			mb_y = blocks[i].y
			mb_speed = blocks[i].speed
		end
	end
	if mb_x == nil then
		return
	end

	-- Read game state
	local gs_entity, gs
	for chunk, entities, count in evolved.execute(self._state_query) do
		local states = chunk:components(C.GameState)
		for i = 1, count do
			gs_entity = entities[i]
			gs = states[i]
		end
	end
	if gs == nil or not gs.active then
		return
	end

	-- Compute overlap: intersection of [mb_x, mb_x+mb_w] with [gs.tower_top_x, gs.tower_top_x+gs.tower_top_w]
	local overlap_x = math.max(mb_x, gs.tower_top_x)
	local overlap_r = math.min(mb_x + mb_w, gs.tower_top_x + gs.tower_top_w)
	local overlap_w = overlap_r - overlap_x

	if overlap_w <= 0 then
		-- Miss — game over
		gs.active = false
		self._bus:emit("stacker:game_over", { score = gs.score })
		return
	end

	-- Score and update state
	gs.score = gs.score + 1
	gs.tower_top_x = overlap_x
	gs.tower_top_w = overlap_w

	local new_y = mb_y
	local color_idx = (gs.score % #COLORS) + 1
	local new_speed = mb_speed + SPEED_INC

	-- Spawn new StackBlock (structural — deferred)
	evolved.defer()
	evolved.spawn({
		[C.StackBlock] = {
			x = overlap_x,
			y = new_y,
			w = overlap_w,
			h = BLOCK_H,
			color = COLORS[color_idx],
		},
	})
	evolved.commit()

	-- Move the moving block up one layer, reset to new width and position
	for chunk, _entities, count in evolved.execute(self._moving_query) do
		local blocks = chunk:components(C.MovingBlock)
		for i = 1, count do
			blocks[i].x = overlap_x
			blocks[i].y = new_y - BLOCK_H
			blocks[i].w = overlap_w
			blocks[i].speed = new_speed
		end
	end

	self._bus:emit("stacker:placed", { score = gs.score, block_w = overlap_w })

	-- Suppress unused variable warning (gs_entity is read during iteration)
	local _ = gs_entity
end

--- Returns true if the game is currently active (not game-over).
--- @return boolean
function StackerPlugin:_is_active()
	for chunk, _entities, count in evolved.execute(self._state_query) do
		local states = chunk:components(C.GameState)
		for i = 1, count do
			return states[i].active
		end
	end
	return false
end

--- Shutdown stub.
--- @param _ctx table
function StackerPlugin:shutdown(_ctx) end

return StackerPlugin
