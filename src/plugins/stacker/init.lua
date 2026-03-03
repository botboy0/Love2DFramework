--- Grid-based stacker game plugin.
--- Classic arcade stacker: a row of cells oscillates left/right on a grid.
--- Player taps to place it. Only the overlapping cells with the row below are kept.
--- Rows shrink on imperfect placements. Game over when width reaches zero.
---
--- Depends on: "input" service (via bus events — no direct service calls).
--- Emits:  stacker:placed   { score, width }
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
StackerPlugin.deps = {}

--- Grid constants
local GRID_COLS = 7
local GRID_ROWS = 14
local START_WIDTH = 4 -- starting row width in cells

--- Derived from screen size at init
local SCREEN_W, SCREEN_H
local CELL_SIZE -- square cells
local GRID_X, GRID_Y -- top-left of grid on screen
local GRID_PX_W, GRID_PX_H

--- Timing
local SPEED_BASE = 0.18 -- seconds per cell move (slower = easier)
local SPEED_MIN = 0.04 -- fastest speed cap
local SPEED_DEC = 0.012 -- seconds faster per row placed

local BLOCK_COLOR = { 0.85, 0.0, 0.85 }

local BG_COLOR = { 0.12, 0.12, 0.15 }
local GRID_LINE_COLOR = { 0.25, 0.25, 0.30 }

--- Recalculate pixel layout from screen dimensions.
local function calc_layout()
	-- Fit grid into screen with padding
	local pad = math.floor(math.min(SCREEN_W, SCREEN_H) * 0.05)
	local avail_w = SCREEN_W - pad * 2
	local avail_h = SCREEN_H * 0.75 -- reserve top 25% for score/header
	CELL_SIZE = math.floor(math.min(avail_w / GRID_COLS, avail_h / GRID_ROWS))
	GRID_PX_W = CELL_SIZE * GRID_COLS
	GRID_PX_H = CELL_SIZE * GRID_ROWS
	GRID_X = math.floor((SCREEN_W - GRID_PX_W) / 2)
	GRID_Y = SCREEN_H - GRID_PX_H - pad
end

--- Spawn helper
local function worlds_spawn(worlds, components)
	if worlds.server then
		return worlds:spawn_server(components)
	else
		return worlds:spawn(components)
	end
end

--- Initialize the plugin.
--- @param ctx table { worlds, bus, config, services, transport }
function StackerPlugin:init(ctx)
	self._bus = ctx.bus
	self._worlds = ctx.worlds

	SCREEN_W = love.graphics.getWidth()
	SCREEN_H = love.graphics.getHeight()
	calc_layout()

	self._stack_query = evolved.builder():include(C.StackRow):build()
	self._moving_query = evolved.builder():include(C.MovingRow):build()
	self._state_query = evolved.builder():include(C.GameState):build()

	self:_spawn_fresh()

	ctx.bus:on("input:action_pressed", function(data)
		if data.action == "place" then
			if self:_is_active() then
				self:_try_place()
			else
				self:_restart()
			end
		end
	end)
end

--- Spawn initial game entities.
function StackerPlugin:_spawn_fresh()
	local start_col = math.floor((GRID_COLS - START_WIDTH) / 2)
	local bottom_row = GRID_ROWS - 1

	worlds_spawn(self._worlds, {
		[C.GameState] = {
			score = 0,
			active = true,
			top_col = start_col,
			top_width = START_WIDTH,
		},
	})

	-- Floor row
	worlds_spawn(self._worlds, {
		[C.StackRow] = {
			col = start_col,
			row = bottom_row,
			width = START_WIDTH,
			color = BLOCK_COLOR,
		},
	})

	-- First moving row
	worlds_spawn(self._worlds, {
		[C.MovingRow] = {
			col = 0,
			row = bottom_row - 1,
			width = START_WIDTH,
			speed = SPEED_BASE,
			dir = 1,
			timer = 0,
		},
	})
end

--- Per-frame update: move the oscillating row cell-by-cell.
--- @param dt number  Delta time in seconds
function StackerPlugin:update(dt)
	if not self:_is_active() then
		return
	end
	for chunk, _entities, count in evolved.execute(self._moving_query) do
		local rows = chunk:components(C.MovingRow)
		for i = 1, count do
			local r = rows[i]
			r.timer = r.timer + dt
			if r.timer >= r.speed then
				r.timer = r.timer - r.speed
				r.col = r.col + r.dir
				-- Bounce off grid edges
				if r.col < 0 then
					r.col = 0
					r.dir = 1
				elseif r.col + r.width > GRID_COLS then
					r.col = GRID_COLS - r.width
					r.dir = -1
				end
			end
		end
	end
end

--- Draw the grid, placed rows, moving row, and UI.
function StackerPlugin:draw()
	-- Background
	love.graphics.setColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3])
	love.graphics.rectangle("fill", GRID_X, GRID_Y, GRID_PX_W, GRID_PX_H)

	-- Grid lines
	love.graphics.setColor(GRID_LINE_COLOR[1], GRID_LINE_COLOR[2], GRID_LINE_COLOR[3])
	for c = 0, GRID_COLS do
		local x = GRID_X + c * CELL_SIZE
		love.graphics.line(x, GRID_Y, x, GRID_Y + GRID_PX_H)
	end
	for r = 0, GRID_ROWS do
		local y = GRID_Y + r * CELL_SIZE
		love.graphics.line(GRID_X, y, GRID_X + GRID_PX_W, y)
	end

	-- Draw placed stack rows
	for chunk, _entities, count in evolved.execute(self._stack_query) do
		local rows = chunk:components(C.StackRow)
		for i = 1, count do
			local s = rows[i]
			love.graphics.setColor(s.color[1], s.color[2], s.color[3])
			for c = 0, s.width - 1 do
				local px = GRID_X + (s.col + c) * CELL_SIZE
				local py = GRID_Y + s.row * CELL_SIZE
				love.graphics.rectangle("fill", px + 1, py + 1, CELL_SIZE - 2, CELL_SIZE - 2)
			end
		end
	end

	-- Draw moving row
	for chunk, _entities, count in evolved.execute(self._moving_query) do
		local rows = chunk:components(C.MovingRow)
		for i = 1, count do
			local m = rows[i]
			love.graphics.setColor(1, 1, 1, 0.9)
			for c = 0, m.width - 1 do
				local px = GRID_X + (m.col + c) * CELL_SIZE
				local py = GRID_Y + m.row * CELL_SIZE
				love.graphics.rectangle("fill", px + 1, py + 1, CELL_SIZE - 2, CELL_SIZE - 2)
			end
		end
	end

	-- Score and game-over text
	love.graphics.setColor(1, 1, 1)
	local score_font_size = math.floor(CELL_SIZE * 0.8)
	love.graphics.printf("STACKER", 0, GRID_Y - CELL_SIZE * 3.5, SCREEN_W, "center")
	for chunk, _entities, count in evolved.execute(self._state_query) do
		local states = chunk:components(C.GameState)
		for i = 1, count do
			local s = states[i]
			love.graphics.printf("Score: " .. tostring(s.score), 0, GRID_Y - CELL_SIZE * 2, SCREEN_W, "center")
			if not s.active then
				love.graphics.setColor(1, 0.3, 0.3)
				love.graphics.printf("GAME OVER", 0, GRID_Y + GRID_PX_H / 2 - CELL_SIZE, SCREEN_W, "center")
				love.graphics.setColor(1, 1, 1, 0.7)
				love.graphics.printf("tap to restart", 0, GRID_Y + GRID_PX_H / 2 + CELL_SIZE * 0.5, SCREEN_W, "center")
			end
		end
	end
end

--- Place the moving row onto the stack.
function StackerPlugin:_try_place()
	local mr_col, mr_width, mr_speed, mr_row
	for chunk, _entities, count in evolved.execute(self._moving_query) do
		local rows = chunk:components(C.MovingRow)
		for i = 1, count do
			mr_col = rows[i].col
			mr_width = rows[i].width
			mr_speed = rows[i].speed
			mr_row = rows[i].row
		end
	end
	if mr_col == nil then
		return
	end

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

	-- Compute overlap in grid cells
	local overlap_left = math.max(mr_col, gs.top_col)
	local overlap_right = math.min(mr_col + mr_width, gs.top_col + gs.top_width)
	local overlap_w = overlap_right - overlap_left

	if overlap_w <= 0 then
		gs.active = false
		self._bus:emit("stacker:game_over", { score = gs.score })
		return
	end

	gs.score = gs.score + 1
	gs.top_col = overlap_left
	gs.top_width = overlap_w

	local new_speed = math.max(SPEED_MIN, mr_speed - SPEED_DEC)
	local next_row = mr_row - 1

	-- Place row at the moving row's position
	evolved.defer()
	worlds_spawn(self._worlds, {
		[C.StackRow] = {
			col = overlap_left,
			row = mr_row,
			width = overlap_w,
			color = BLOCK_COLOR,
		},
	})
	evolved.commit()

	-- Check if tower reached the top
	if next_row < 0 then
		gs.active = false
		self._bus:emit("stacker:game_over", { score = gs.score })
		return
	end

	-- Move the moving row up one
	for chunk, _entities, count in evolved.execute(self._moving_query) do
		local rows = chunk:components(C.MovingRow)
		for i = 1, count do
			rows[i].col = 0
			rows[i].row = next_row
			rows[i].width = overlap_w
			rows[i].speed = new_speed
			rows[i].timer = 0
			rows[i].dir = 1
		end
	end

	self._bus:emit("stacker:placed", { score = gs.score, width = overlap_w })
	local _ = gs_entity
end

--- Returns true if the game is currently active.
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

--- Handle screen resize.
--- @param w number  New screen width
--- @param h number  New screen height
function StackerPlugin:resize(w, h)
	SCREEN_W = w
	SCREEN_H = h
	calc_layout()
end

--- Restart the game.
function StackerPlugin:_restart()
	evolved.defer()
	for chunk, entities, count in evolved.execute(self._stack_query) do
		for i = 1, count do
			evolved.destroy(entities[i])
		end
	end
	for chunk, entities, count in evolved.execute(self._moving_query) do
		for i = 1, count do
			evolved.destroy(entities[i])
		end
	end
	for chunk, entities, count in evolved.execute(self._state_query) do
		for i = 1, count do
			evolved.destroy(entities[i])
		end
	end
	self:_spawn_fresh()
	evolved.commit()
	self._bus:emit("stacker:reset", {})
end

--- Shutdown stub.
--- @param _ctx table
function StackerPlugin:shutdown(_ctx) end

return StackerPlugin
