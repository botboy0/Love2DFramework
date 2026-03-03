--- Shared ECS fragment IDs for all game plugins.
--- Games define their own fragments here; the framework is genre-agnostic.

local evolved = require("lib.evolved")

--- StackRow:    { col, row, width, color } — a placed row on the tower (grid coords).
--- MovingRow:   { col, row, width, speed, dir, timer } — the oscillating row (grid coords).
--- GameState:   { score, active, top_col, top_width, current_row } — singleton game state.
local StackRow, MovingRow, GameState = evolved.id(3)

return {
	StackRow = StackRow,
	MovingRow = MovingRow,
	GameState = GameState,
}
