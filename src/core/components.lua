--- Shared component fragment definitions.
--- All fragment IDs are created once here and used by both server and client worlds.
--- This is the single source of truth for component identity in the ECS.

local evolved = require("lib.evolved")

local Components = {}

-- Core fragments — used by both server and client worlds.
-- evolved.id(3) returns 3 unique integer IDs in a single call.
Components.Position, Components.Velocity, Components.Health = evolved.id(3)

return Components
