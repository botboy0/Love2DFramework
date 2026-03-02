---
phase: quick-3
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - src/core/registry.lua
  - src/core/components.lua
  - src/plugins/stacker/init.lua
  - src/core/plugin_list.lua
  - main.lua
  - tests/core/registry_spec.lua
  - tests/plugins/stacker/init_spec.lua
autonomous: true
requirements: []

must_haves:
  truths:
    - "A moving block oscillates left/right across the screen each frame"
    - "Player presses 'place' to stack the block on top of the previous layer"
    - "Only the overlapping portion with the layer below is kept; overhanging area is cut off"
    - "The moving block gets narrower each imperfect placement"
    - "Game ends when block width reaches zero and a 'stacker:game_over' event is emitted"
    - "Score increments by 1 for each successful placement and is readable from the ECS world"
    - "The stacked tower and current moving block are rendered as colored rectangles on screen"
  artifacts:
    - path: "src/core/components.lua"
      provides: "Stacker ECS fragment IDs: StackBlock, MovingBlock, GameState"
      contains: "evolved.id"
    - path: "src/plugins/stacker/init.lua"
      provides: "Full stacker plugin — update loop, draw, input handling via bus events"
      exports: ["StackerPlugin"]
    - path: "src/core/registry.lua"
      provides: "Registry:draw_all() method for rendering plugins"
      contains: "draw_all"
    - path: "main.lua"
      provides: "Stacker input config, draw_all wiring in love.draw()"
      contains: "_config.input"
    - path: "tests/plugins/stacker/init_spec.lua"
      provides: "Plugin harness specs for stacker logic"
  key_links:
    - from: "main.lua"
      to: "src/core/registry.lua"
      via: "_registry:draw_all() in love.draw()"
      pattern: "draw_all"
    - from: "src/plugins/stacker/init.lua"
      to: "src/core/components.lua"
      via: "local C = require('src.core.components')"
      pattern: "require.*components"
    - from: "src/plugins/stacker/init.lua"
      to: "input service"
      via: "ctx.bus:on('input:action_pressed') for 'place' action"
      pattern: "input:action_pressed"
---

<objective>
Create a playable stacker arcade game as a Love2D ECS plugin.

Purpose: Demonstrate the framework's plugin architecture with a complete game loop —
ECS state, event-bus input, draw wiring, and passing CI (lint + format + tests + validate).

Output:
- Registry gains draw_all() (mirrors update_all pattern)
- main.lua gains stacker input bindings and calls draw_all in love.draw()
- src/plugins/stacker/ — self-contained stacker game plugin
- src/core/components.lua — stacker fragment IDs
- Busted specs that pass CI
</objective>

<execution_context>
@/home/botboy0/.claude/get-shit-done/workflows/execute-plan.md
@/home/botboy0/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@examples/canonical_plugin.lua
@src/core/registry.lua
@src/plugins/input/init.lua
@tests/helpers/plugin_harness.lua
@main.lua
@src/core/plugin_list.lua

<interfaces>
<!-- Key contracts the executor needs. No codebase exploration required. -->

From src/core/registry.lua (existing pattern to mirror for draw_all):
```lua
-- update_all pattern (lines 246-270) — draw_all must mirror this exactly:
function Registry:update_all(dt)
    if self._error_mode == "tolerant" then
        for _, entry in ipairs(self._boot_order) do
            if entry.module.update then
                local ok, err = pcall(entry.module.update, entry.module, dt)
                -- log on failure, continue
            end
        end
    else
        for _, entry in ipairs(self._boot_order) do
            if entry.module.update then
                entry.module:update(dt)
            end
        end
    end
end
```

From lib/evolved.lua ECS API:
```lua
local evolved = require("lib.evolved")
-- Create N fragment IDs at once:
local FragA, FragB, FragC = evolved.id(3)
-- Spawn entity with fragments:
local e = evolved.spawn({ [FragA] = value, [FragB] = value2 })
-- Get/set:
local v = evolved.get(e, FragA)
evolved.set(e, FragA, new_val)
-- Structural mutations (create/destroy) must be deferred:
evolved.defer()
evolved.destroy(e)
evolved.set(e, NewFrag, val)  -- adding a new fragment is also structural
evolved.commit()
-- Query iteration:
local q = evolved.builder():include(FragA, FragB):build()
for chunk, _entities, count in evolved.execute(q) do
    local a_comps, b_comps = chunk:components(FragA, FragB)
    for i = 1, count do
        -- mutate a_comps[i], b_comps[i] in-place (non-structural)
    end
end
```

From src/plugins/input/init.lua (bus events emitted):
```lua
-- Discrete press/release events:
bus:emit("input:action_pressed",  { action = "place", device = "..." })
bus:emit("input:action_released", { action = "place", device = "..." })
```

From tests/helpers/plugin_harness.lua:
```lua
local harness = require("tests.helpers.plugin_harness")
local ctx = harness.create_context({
    config = { input = { place = { key = "space", sc = "space" } } },
    deps   = { input = { is_pressed = function() return false end, ... } },
    allowed_deps = { "input" },
})
MyPlugin:init(ctx)
-- ... assertions ...
harness.teardown(ctx, spawned_entities)
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add Registry:draw_all, wire love.draw, add stacker input config</name>
  <files>src/core/registry.lua, main.lua</files>
  <action>
**src/core/registry.lua** — add `draw_all()` method immediately after `update_all()` (around line 271), mirroring its tolerant/strict pattern exactly:

```lua
--- Call draw() on all booted plugins in boot order.
--- Plugins without a draw method are silently skipped.
--- In strict mode (default): errors from plugin:draw propagate.
--- In tolerant mode: errors from plugin:draw are logged; remaining plugins still draw.
--- Safe to call before boot() — _boot_order is empty so it is a no-op.
function Registry:draw_all()
    if self._error_mode == "tolerant" then
        for _, entry in ipairs(self._boot_order) do
            if entry.module.draw then
                local ok, err = pcall(entry.module.draw, entry.module)
                if not ok then
                    self._log(
                        string.format(
                            "[Registry] Plugin '%s' draw failed (tolerant mode): %s",
                            entry.name,
                            tostring(err)
                        )
                    )
                end
            end
        end
    else
        for _, entry in ipairs(self._boot_order) do
            if entry.module.draw then
                entry.module:draw()
            end
        end
    end
end
```

**main.lua** — two changes:

1. Add stacker input config inside `_config`:
```lua
local _config = {
    input = {
        place = { key = "space", sc = "space" },
    },
}
```

2. Wire `love.draw()` to call `draw_all`:
```lua
function love.draw()
    if not _registry then
        return
    end
    _registry:draw_all()
end
```

Run stylua on both files after editing: `stylua src/core/registry.lua main.lua`
  </action>
  <verify>
    <automated>lua -e "local R = require('src.core.registry'); local r = R.new(); assert(type(r.draw_all) == 'function', 'draw_all missing'); print('ok')"</automated>
  </verify>
  <done>Registry:draw_all() exists and mirrors update_all pattern; love.draw() calls _registry:draw_all(); _config.input has 'place' action bound to spacebar.</done>
</task>

<task type="auto">
  <name>Task 2: Create stacker plugin with ECS fragments and game logic</name>
  <files>src/core/components.lua, src/plugins/stacker/init.lua, src/core/plugin_list.lua</files>
  <action>
**src/core/components.lua** — define stacker fragment IDs (file currently returns {}):

```lua
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
```

**src/plugins/stacker/init.lua** — full plugin. Game constants at top:

```lua
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

local evolved = require("lib.evolved")
local C = require("src.core.components")

local StackerPlugin = {}
StackerPlugin.__index = StackerPlugin

StackerPlugin.name = "stacker"
StackerPlugin.deps = {}  -- uses bus events from input, not direct service dep

--- Game constants
local SCREEN_W      = 1280
local SCREEN_H      = 720
local BLOCK_H       = 30       -- height of each layer
local START_W       = 300      -- width of first block
local SPEED_BASE    = 250      -- px/s initial oscillation speed
local SPEED_INC     = 20       -- px/s speed increase per successful placement
local FLOOR_Y       = SCREEN_H - 60  -- y position of the bottom layer
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
    self._bus    = ctx.bus
    self._worlds = ctx.worlds

    -- Queries built at init, reused every frame
    self._moving_query = evolved.builder():include(C.MovingBlock):build()
    self._stack_query  = evolved.builder():include(C.StackBlock):build()
    self._state_query  = evolved.builder():include(C.GameState):build()

    -- Spawn singleton GameState
    evolved.spawn({
        [C.GameState] = {
            score        = 0,
            active       = true,
            tower_top_x  = (SCREEN_W - START_W) / 2,
            tower_top_w  = START_W,
        },
    })

    -- Spawn the floor block (layer 0)
    evolved.spawn({
        [C.StackBlock] = {
            x     = (SCREEN_W - START_W) / 2,
            y     = FLOOR_Y,
            w     = START_W,
            h     = BLOCK_H,
            color = COLORS[1],
        },
    })

    -- Spawn the first moving block one layer above the floor
    evolved.spawn({
        [C.MovingBlock] = {
            x     = (SCREEN_W - START_W) / 2,
            y     = FLOOR_Y - BLOCK_H,
            w     = START_W,
            h     = BLOCK_H,
            speed = SPEED_BASE,
            dir   = 1,
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
                    b.x  = 0
                    b.dir = 1
                elseif b.x + b.w > SCREEN_W then
                    b.x  = SCREEN_W - b.w
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
            mb_x     = blocks[i].x
            mb_w     = blocks[i].w
            mb_y     = blocks[i].y
            mb_speed = blocks[i].speed
        end
    end
    if mb_x == nil then return end

    -- Read game state
    local gs_entity, gs
    for chunk, entities, count in evolved.execute(self._state_query) do
        local states = chunk:components(C.GameState)
        for i = 1, count do
            gs_entity = entities[i]
            gs        = states[i]
        end
    end
    if gs == nil or not gs.active then return end

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
    gs.score       = gs.score + 1
    gs.tower_top_x = overlap_x
    gs.tower_top_w = overlap_w

    local new_y    = mb_y
    local color_idx = ((gs.score) % #COLORS) + 1
    local new_speed = mb_speed + SPEED_INC

    -- Spawn new StackBlock (structural — deferred)
    evolved.defer()
    evolved.spawn({
        [C.StackBlock] = {
            x     = overlap_x,
            y     = new_y,
            w     = overlap_w,
            h     = BLOCK_H,
            color = COLORS[color_idx],
        },
    })
    evolved.commit()

    -- Move the moving block up one layer, reset to new width and position
    for chunk, _entities, count in evolved.execute(self._moving_query) do
        local blocks = chunk:components(C.MovingBlock)
        for i = 1, count do
            blocks[i].x     = overlap_x
            blocks[i].y     = new_y - BLOCK_H
            blocks[i].w     = overlap_w
            blocks[i].speed = new_speed
        end
    end

    self._bus:emit("stacker:placed", { score = gs.score, block_w = overlap_w })
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
```

**src/core/plugin_list.lua** — add stacker entry after assets:

```lua
{
    name = "stacker",
    module = "src.plugins.stacker",
    deps = {},
},
```

Run stylua on all three files: `stylua src/core/components.lua src/plugins/stacker/init.lua src/core/plugin_list.lua`
  </action>
  <verify>
    <automated>busted --pattern=stacker 2>&1 || echo "run after task 3 creates specs"</automated>
  </verify>
  <done>src/plugins/stacker/init.lua exists with StackerPlugin; src/core/components.lua exports StackBlock, MovingBlock, GameState; stacker is in plugin_list.lua.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Write busted specs for stacker plugin and registry draw_all</name>
  <files>tests/plugins/stacker/init_spec.lua, tests/core/registry_spec.lua</files>
  <behavior>
    - Test: stacker:init spawns exactly 1 GameState entity, 1 StackBlock (floor), 1 MovingBlock
    - Test: stacker:update(dt) moves the moving block x position by speed*dir*dt
    - Test: stacker:update(dt) reverses dir when block reaches right edge (x + w >= SCREEN_W)
    - Test: stacker:update(dt) does NOT move block when game is inactive (gs.active = false)
    - Test: 'input:action_pressed' with action='place' trims moving block to overlap width
    - Test: 'input:action_pressed' with action='place' increments score by 1
    - Test: 'input:action_pressed' with action='place' and zero overlap emits 'stacker:game_over'
    - Test: 'input:action_pressed' with action='place' and zero overlap sets gs.active = false
    - Test: registry draw_all calls draw() on plugins that have a draw method
    - Test: registry draw_all skips plugins without a draw method (no error)
  </behavior>
  <action>
**tests/plugins/stacker/init_spec.lua** — write specs using plugin_harness. Key patterns:

- Use `harness.create_context({ config = { input = { place = { key = "space", sc = "space" } } } })`
- Call `StackerPlugin:init(ctx)` then flush bus before assertions: `ctx.bus:flush()`
- After init, query evolved for GameState, StackBlock, MovingBlock to assert spawn counts
- To test placement: manually set MovingBlock position to partial overlap, then emit `input:action_pressed` with `{ action = "place" }` and flush bus
- Use `harness.teardown(ctx)` in after_each — also call `evolved.defer(); evolved.collect(); evolved.commit()` to clear all entities between tests (or track spawned entities carefully)
- Import: `local StackerPlugin = require("src.plugins.stacker")`
- Import: `local C = require("src.core.components")`
- Import: `local evolved = require("lib.evolved")`

For entity counting, iterate a query and count:
```lua
local function count_query(q)
    local n = 0
    for _chunk, _entities, count in evolved.execute(q) do
        n = n + count
    end
    return n
end
```

**tests/core/registry_spec.lua** — add draw_all tests to the existing spec file if it exists, or create it:

```lua
-- draw_all test stubs:
-- Plugin with draw: assert draw() called during draw_all
-- Plugin without draw: assert no error during draw_all
-- Tolerant mode: draw error logged, other plugins still draw
```

After writing specs, run: `busted` — all tests must pass (green).
Run selene and stylua checks: `selene tests/plugins/stacker/ tests/core/registry_spec.lua` and `stylua --check tests/plugins/stacker/init_spec.lua tests/core/registry_spec.lua`
  </action>
  <verify>
    <automated>busted 2>&1</automated>
  </verify>
  <done>busted exits 0; stacker specs cover init spawn counts, movement, placement overlap, game_over; registry draw_all spec covers call-through and skip-no-draw.</done>
</task>

</tasks>

<verification>
After all three tasks:

1. `busted` — all specs pass, zero failures
2. `selene src/ main.lua conf.lua` — zero errors
3. `stylua --check src/ main.lua conf.lua` — zero formatting issues
4. `lua scripts/validate_architecture.lua` — no cross-plugin import violations, no missing test files
5. `scripts/full-check.sh` — all four CI steps pass
</verification>

<success_criteria>
- `love.draw()` calls `_registry:draw_all()` and stacker blocks render on screen
- Pressing spacebar places the moving block; only the overlap region remains
- Score increments each successful placement; game ends on a miss
- `busted` exits 0, `selene` exits 0, `stylua --check` exits 0, `validate_architecture.lua` exits 0
- No globals introduced; all state lives in ECS entities
</success_criteria>

<output>
After completion, create `.planning/quick/3-create-a-simple-stacker-game-using-the-f/3-SUMMARY.md`
</output>
