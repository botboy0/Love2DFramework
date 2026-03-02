--- Shared ECS fragment IDs for all game plugins.
--- Games define their own fragments here; the framework is genre-agnostic.

local evolved = require("lib.evolved")

--- StackBlock: { x, y, w, h, color } — a placed block on the tower.
--- MovingBlock: { x, y, w, h, speed, dir } — the current oscillating block.
--- GameState:   { score, active, tower_top_x, tower_top_w } — singleton game state.
local StackBlock, MovingBlock, GameState = evolved.id(3)

return {
	StackBlock = StackBlock,
	MovingBlock = MovingBlock,
	GameState = GameState,
}
