--- Shared component fragment definitions.
--- All fragment IDs are created here and used by both server and client worlds.
--- This is the single source of truth for component identity in the ECS.
---
--- This file ships EMPTY. Each game defines its own components:
---   Components.Position, Components.Velocity = evolved.id(2)
---
--- Do NOT define components in plugin files — only here.
--- The architecture validator (Phase 2) enforces this rule.

return {}
