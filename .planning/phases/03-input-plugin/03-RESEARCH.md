# Phase 3: Input Plugin - Research

**Researched:** 2026-03-02
**Domain:** Love2D input abstraction — baton library, touch regions, bus integration, service API
**Confidence:** HIGH

## Summary

Phase 3 introduces a unified input plugin that wraps the baton library (v1.0.2) to abstract keyboard, gamepad, and touch input behind an action-based service API. The architecture decision is already locked: baton handles keyboard and gamepad; touch is implemented as a custom rectangular-region overlay (baton has no touch support). The plugin follows the standard `plugin:init(ctx)` / `plugin:quit()` lifecycle and exposes query methods via `ctx.services`.

The key design tension is that baton is not a drop-in solution for all three input modes. Baton covers keyboard + gamepad with a clean action-based API (`down()`, `pressed()`, `released()`, `getActiveDevice()`). Touch regions must be implemented from scratch using Love2D's `love.touchpressed` / `love.touchreleased` callbacks or `love.touch.getTouches()` polling. The plugin must bridge these two subsystems into a single unified service.

Testing without physical devices is tractable: baton's internal state table can be directly written to in tests (bypassing `update()`), and the touch state table is fully owned by the plugin so it can be injected in test contexts. No physical device is required.

**Primary recommendation:** Vendor baton into `lib/baton.lua`. Implement touch region tracking as a thin layer inside the plugin. Expose a single `input` service that unifies both. Use `love.joystickadded` / `love.joystickremoved` as thin pass-throughs in `main.lua` forwarded to the plugin's handler methods.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Action mapping design:**
- Actions defined via `ctx.config.input` config table — follows established config pattern
- No default bindings — games must explicitly declare all actions
- Include commented-out examples in config section showing the table structure for developer guidance
- Multiple bindings per device supported via arrays (e.g., `{ key = {'space', 'w'}, gamepad = 'a' }`)
- Runtime rebinding supported — bindings can be changed after init (baton supports this natively)

**Input query API:**
- Hybrid model: intent events on the bus for discrete actions (jump, interact), polling via service for continuous axes (movement, aiming)
- Service exposes full state queries: `is_down(action)`, `is_pressed(action)`, `is_released(action)`, `get_axis(action)`
- Active device tracking: `get_active_device()` returns which device (keyboard/gamepad) was last used
- Plugin uses explicit `update(dt)` call — follows canonical plugin pattern, no Love2D callback hooks for update
- Love2D callbacks (`love.gamepadpressed`, `love.gamepadaxis`, etc.) forwarded as thin pass-throughs in main.lua for gamepad hot-plugging

**Touch input strategy:**
- Basic rectangular touch regions mapped to actions — digital on/off only (tap region = action pressed)
- Config supports `unit` field on touch regions: `"px"` (default if omitted) or `"pct"` (screen-relative percentage)
  - Pixels: `{ touch = { x = 0, y = 400, w = 120, h = 120 } }` or `{ touch = { x = 0, y = 400, w = 120, h = 120, unit = "px" } }`
  - Percentage: `{ touch = { x = 0, y = 0.8, w = 0.15, h = 0.15, unit = "pct" } }`
- Raw touch position accessor exposed via service (`get_touch_points()`) — for games that need to know where the user tapped, independent of action regions
- No gestures, virtual sticks, multi-touch combos, or analog touch axes — deferred
- No debug overlay for touch regions — visualization belongs in Phase 6 (Developer Tools)

**Bus event integration:**
- Discrete actions emit: `input:action_pressed` / `input:action_released` with payload `{ action = "jump", device = "keyboard" }`
- Device events: `input:device_changed` with `{ device = "gamepad" }` when active input device switches
- Gamepad lifecycle: `input:gamepad_connected` / `input:gamepad_disconnected`
- Continuous axes are polling-only — no bus events for axis state (avoids per-frame bus spam)

### Claude's Discretion
- Baton vendoring and integration approach
- Internal update order (when baton update happens relative to bus flush)
- Deadzone handling for gamepad axes
- Exact service API method signatures and naming
- Test mocking strategy for input without physical devices

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INPT-01 | Unified input plugin wrapping baton for keyboard, gamepad, and touch | Baton API verified — covers keyboard + gamepad. Touch layer is custom-built using Love2D touch callbacks. Both unified under single service. |
| INPT-02 | Action-based input mapping abstracted from hardware devices | Baton's `controls` config + custom touch region config maps hardware sources to named actions. Service API hides device details from callers. |
| INPT-03 | Input plugin registered as standard framework plugin via `plugin:init(ctx)` | Standard plugin pattern (`plugin:init(ctx)`, `plugin:update(dt)`, `plugin:shutdown(_ctx)`) and `plugin_list.lua` registration verified in codebase. |
</phase_requirements>

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| baton | 1.0.2 (MIT, 2020) | Action-based keyboard + gamepad input abstraction | The locked decision. Provides `down()`, `pressed()`, `released()`, `getActiveDevice()`, `get()` for axes, runtime-rebindable `player.config.controls`. |
| Love2D touch API | Built-in | Touch event tracking (`love.touchpressed`, `love.touchreleased`, `love.touch.getTouches`) | No library needed — Love2D provides raw touch events that the plugin manages directly. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| evolved.lua | Already vendored in `lib/` | ECS world | Not used for input — input is service-based, not entity-based. No input ECS components anticipated. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| baton | tactile (also by tesselode) | Tactile is newer but less established in the ecosystem; baton is locked decision. |
| Custom touch layer | baton | Baton has zero touch support; custom layer is the only option. |

**Installation:**

Vendor manually — download `baton.lua` and place at `lib/baton.lua`. No package manager in this stack.

---

## Architecture Patterns

### Recommended Project Structure

```
src/plugins/input/
    init.lua              -- Plugin entry: init, update, shutdown, service registration
    touch_regions.lua     -- Touch region state: parse config, track active touches, hit test
lib/
    baton.lua             -- Vendored baton library
tests/plugins/input/
    input_plugin_spec.lua -- Plugin lifecycle, service API, bus events
    touch_regions_spec.lua -- Region config parsing, hit testing, state management
```

### Pattern 1: Baton Player Creation

**What:** Create a baton player from `ctx.config.input` at init time, translating the project's config format to baton's format.

**When to use:** During `InputPlugin:init(ctx)`.

**Example:**

```lua
-- Source: baton README / verified API
local baton = require("lib.baton")

function InputPlugin:init(ctx)
    local input_config = ctx.config.input or {}
    local baton_controls = {}

    -- Translate project config format to baton format
    -- Project format: { jump = { key = {'space', 'w'}, gamepad = 'a' } }
    -- Baton format:   { jump = {'key:space', 'key:w', 'button:a'} }
    for action, binding in pairs(input_config) do
        local sources = {}
        if binding.key then
            local keys = type(binding.key) == "table" and binding.key or { binding.key }
            for _, k in ipairs(keys) do
                table.insert(sources, "key:" .. k)
            end
        end
        if binding.gamepad then
            local btns = type(binding.gamepad) == "table" and binding.gamepad or { binding.gamepad }
            for _, b in ipairs(btns) do
                table.insert(sources, "button:" .. b)
            end
        end
        baton_controls[action] = sources
    end

    -- Create baton player (no joystick yet — set on joystickadded)
    self._player = baton.new({
        controls = baton_controls,
        deadzone = ctx.config.input_deadzone or 0.2,
    })
end
```

### Pattern 2: Update Order

**What:** baton's `update()` must be called before querying state. Bus events for discrete actions must be emitted after baton's state is fresh but before bus flush. Touch region state is updated alongside baton.

**When to use:** In `InputPlugin:update(dt)`.

**Example:**

```lua
function InputPlugin:update(_dt)
    -- 1. Update baton state (keyboard + gamepad)
    self._player:update()

    -- 2. Update touch region state
    self._touch_regions:update()

    -- 3. Detect pressed/released transitions and emit bus events
    --    (bus uses deferred dispatch; events queued here, delivered on bus:flush())
    for action, _ in pairs(self._actions) do
        local pressed = self._player:pressed(action) or self._touch_regions:pressed(action)
        local released = self._player:released(action) or self._touch_regions:released(action)
        if pressed then
            self._bus:emit("input:action_pressed", {
                action = action,
                device = self:get_active_device(),
            })
        end
        if released then
            self._bus:emit("input:action_released", {
                action = action,
                device = self:get_active_device(),
            })
        end
    end

    -- 4. Detect device changes
    local current_device = self._player:getActiveDevice()
    if current_device ~= self._last_device then
        self._last_device = current_device
        self._bus:emit("input:device_changed", { device = current_device })
    end
end
```

**Important ordering note:** `plugin:update(dt)` is called by the game loop, which runs before `bus:flush()`. This means bus events emitted during `update()` are delivered in the same frame's flush — consistent with the established transport ordering in `main.lua`.

### Pattern 3: Gamepad Hot-Plug Pass-Through

**What:** Love2D calls `love.joystickadded` when a gamepad connects (including at startup). `main.lua` forwards these to the input plugin as thin pass-throughs.

**When to use:** In `main.lua`, add stubs that delegate to the plugin.

**Example:**

```lua
-- main.lua additions
function love.joystickadded(joystick)
    -- Forward to input plugin if loaded
    if _input_plugin then
        _input_plugin:on_joystick_added(joystick)
    end
end

function love.joystickremoved(joystick)
    if _input_plugin then
        _input_plugin:on_joystick_removed(joystick)
    end
end
```

```lua
-- src/plugins/input/init.lua — handler methods
function InputPlugin:on_joystick_added(joystick)
    if joystick:isGamepad() and not self._joystick then
        self._joystick = joystick
        self._player.config.joystick = joystick
        self._bus:emit("input:gamepad_connected", { joystick = joystick })
    end
end

function InputPlugin:on_joystick_removed(joystick)
    if self._joystick == joystick then
        self._joystick = nil
        self._player.config.joystick = nil
        self._bus:emit("input:gamepad_disconnected", { joystick = joystick })
    end
end
```

**Note:** `love.joystickadded` fires at startup for already-connected controllers. This means the plugin handles the initial gamepad assignment the same as hot-plug — no special-casing needed.

### Pattern 4: Touch Region State Machine

**What:** Touch regions are tracked via Love2D's `love.touchpressed` / `love.touchreleased` callbacks, mapped to a per-action pressed/down/released state that mirrors baton's API shape.

**When to use:** In `touch_regions.lua`.

**Example:**

```lua
-- touch_regions.lua internal state
local TouchRegions = {}
TouchRegions.__index = TouchRegions

function TouchRegions.new(config)
    local regions = {}
    for action, binding in pairs(config) do
        if binding.touch then
            local r = binding.touch
            regions[action] = {
                x = r.x, y = r.y, w = r.w, h = r.h,
                unit = r.unit or "px",
                _active_ids = {},  -- set of touch IDs currently in this region
                _down = false,
                _pressed = false,
                _released = false,
            }
        end
    end
    return setmetatable({ _regions = regions }, TouchRegions)
end

-- Called from love.touchpressed pass-through
function TouchRegions:on_touch_pressed(id, x, y)
    for _, region in pairs(self._regions) do
        local rx, ry, rw, rh = self:_resolve_rect(region)
        if x >= rx and x < rx + rw and y >= ry and y < ry + rh then
            region._active_ids[id] = true
        end
    end
end

-- update() called from plugin:update() — computes transitions
function TouchRegions:update()
    for _, region in pairs(self._regions) do
        local was_down = region._down
        local is_down = next(region._active_ids) ~= nil
        region._down = is_down
        region._pressed = is_down and not was_down
        region._released = not is_down and was_down
    end
end

function TouchRegions:pressed(action)
    return self._regions[action] and self._regions[action]._pressed or false
end

function TouchRegions:down(action)
    return self._regions[action] and self._regions[action]._down or false
end

function TouchRegions:released(action)
    return self._regions[action] and self._regions[action]._released or false
end
```

### Pattern 5: Service Registration

**What:** The plugin registers an `input` service via `ctx.services:register()` that exposes the unified query API. Matches the canonical plugin pattern exactly.

**Example:**

```lua
ctx.services:register("input", {
    is_down     = function(action) return self:_is_down(action) end,
    is_pressed  = function(action) return self:_is_pressed(action) end,
    is_released = function(action) return self:_is_released(action) end,
    get_axis    = function(action) return self._player:get(action) end,
    get_active_device  = function() return self._player:getActiveDevice() end,
    get_touch_points   = function() return love.touch.getTouches() end,
    get_touch_regions  = function() return self._touch_regions:get_region_defs() end,
})
```

### Pattern 6: Test Mocking Strategy

**What:** Tests avoid physical devices by directly writing baton's internal state and injecting touch events. No love.keyboard, love.joystick, or real device required.

**When to use:** In all `_spec.lua` test files for this plugin.

**Example:**

```lua
-- Mock baton player state directly for unit testing
local function make_mock_player(overrides)
    return {
        update = function() end,
        down = function(_, action) return overrides.down and overrides.down[action] or false end,
        pressed = function(_, action) return overrides.pressed and overrides.pressed[action] or false end,
        released = function(_, action) return overrides.released and overrides.released[action] or false end,
        get = function(_, action) return overrides.axes and overrides.axes[action] or 0 end,
        getActiveDevice = function() return overrides.device or "kbm" end,
        config = { controls = {}, joystick = nil, deadzone = 0.2 },
    }
end

-- In tests: inject mock player
InputPlugin._player = make_mock_player({ pressed = { jump = true } })
InputPlugin:update(0)
-- Then assert bus received input:action_pressed for "jump"
```

For touch region testing, inject events directly:
```lua
-- Simulate a touch press at a known coordinate
plugin._touch_regions:on_touch_pressed("id1", 50, 420)
plugin._touch_regions:update()
assert.is_true(plugin._touch_regions:pressed("move_left"))
```

### Anti-Patterns to Avoid

- **Checking device in game code:** Service callers should never branch on `get_active_device()` for game logic. Use it only for UI display (prompt icons). Logic must use `is_down(action)` only.
- **Emitting axis events on the bus:** Axes are polling-only. Emitting per-frame axis values on the bus would cause O(actions) events per frame and trigger the re-entrancy guard.
- **Calling `baton:update()` in a Love2D callback:** baton must be updated in the explicit `plugin:update(dt)` call, not in `love.keypressed` or similar. The canonical plugin pattern uses explicit `update(dt)`.
- **Storing touch IDs as integers:** Love2D touch IDs are lightuserdata (pointers), not integers. Use them as table keys directly — do not cast to numbers.
- **Single-joystick assumption in tests:** Tests that require a specific joystick object will break in CI. Always use the mock player pattern.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Keyboard/gamepad deadzone, state tracking, frame transitions | Custom input state machine | baton | baton handles `pressed()`/`released()` frame transitions, deadzone, active device detection — all the edge cases |
| Scancode vs key constant distinction | Custom key lookup tables | baton `key:` vs `sc:` source types | baton already models this distinction |
| Axis normalization and square deadzone | Custom vector math | baton `squareDeadzone` config option | Non-trivial to get right; baton handles it |

**Key insight:** Touch regions are genuinely not handled by any library — this is the one area where custom code is unavoidable and appropriate. Keep it simple: rectangular hit test only, no fancy geometry.

---

## Common Pitfalls

### Pitfall 1: baton update() Before Query

**What goes wrong:** If `baton:update()` is not called at the start of each frame, `pressed()` and `released()` always return false (they are frame-differential states).

**Why it happens:** baton computes transitions during `update()`, not lazily on query.

**How to avoid:** Always call `self._player:update()` as the first line of `InputPlugin:update(dt)`.

**Warning signs:** `is_pressed()` always returns false in tests — check if `update()` is being called in the test.

### Pitfall 2: Touch ID Reuse

**What goes wrong:** Love2D touch IDs are only unique for the duration of a single touch press. After `love.touchreleased`, that ID may be reused by the next `love.touchpressed`. Storing old IDs causes ghost presses.

**Why it happens:** IDs are memory pointers (lightuserdata), not incrementing integers.

**How to avoid:** In `on_touch_released(id, ...)`, remove `id` from all active region sets. Never hold onto IDs past the released callback.

**Warning signs:** Touch regions appear permanently "held down" after fast tapping.

### Pitfall 3: Bus Re-Entrancy During Update

**What goes wrong:** The bus has a re-entrancy guard. Emitting bus events during `bus:flush()` is silently discarded. If input events are emitted during flush (not before), they are lost.

**Why it happens:** `plugin:update()` is called by the game loop — but if someone accidentally calls it from a bus handler (during flush), emissions would be silently dropped.

**How to avoid:** Plugin update must be called from `love.update()` before `bus:flush()`. The existing `main.lua` ordering is: receive transport → `bus:flush()` → `transport:flush()`. Plugin updates should be called before this sequence (or integrated into it as a pre-flush step).

**Warning signs:** Discrete action events (`input:action_pressed`) are never received by subscribers.

**Resolution:** Game loop must call all `plugin:update(dt)` methods before `bus:flush()`. This needs to be established in `main.lua` — either by the registry exposing an `update_all(dt)` method or by explicit calls.

### Pitfall 4: Config Translation Shape

**What goes wrong:** The project's config format (`{ jump = { key = 'space', gamepad = 'a' } }`) is not baton's format (`{ jump = {'key:space', 'button:a'} }`). Passing the project config directly to baton will silently produce no bindings (baton won't error — it just won't recognize the source strings).

**Why it happens:** Baton uses a specific `'type:source'` string format.

**How to avoid:** The translation step in `init()` is mandatory. Write a test that verifies `is_down('jump')` returns true when the mock player reports down for that action.

**Warning signs:** `is_down(action)` always returns false despite correct config.

### Pitfall 5: Plugin Update Loop Missing

**What goes wrong:** The canonical plugin pattern shows `plugin:update(dt)`, but the current `main.lua` does not call `plugin:update()` on any plugin (it only boots and shuts down). The registry must be extended or `main.lua` updated to call updates.

**Why it happens:** Phase 1 and 2 plugins have no update behavior. This is the first plugin that requires per-frame update.

**How to avoid:** This is a real architectural gap to address in this phase. Options:
1. `main.lua` calls `_registry:update_all(dt)` (preferred — registry owns plugin lifecycle)
2. `main.lua` hard-codes a call to the input plugin (violates architecture rules — do not do this)

The registry will need an `update_all(dt)` method (or equivalent) to call `plugin:update(dt)` on all registered plugins that have an `update` method. This is a **prerequisite** to the input plugin working at runtime.

**Warning signs:** Input plugin spec passes but the plugin never actually updates in the game.

---

## Code Examples

Verified patterns from official sources and codebase inspection:

### Baton Player Creation

```lua
-- Source: baton API (verified via WebFetch of baton.lua)
local baton = require("lib.baton")

local player = baton.new({
    controls = {
        jump  = { 'key:space', 'button:a' },
        left  = { 'key:left', 'key:a', 'axis:leftx-', 'button:dpleft' },
        right = { 'key:right', 'key:d', 'axis:leftx+', 'button:dpright' },
    },
    joystick = love.joystick.getJoysticks()[1],  -- nil if none connected
    deadzone = 0.2,
})

-- Each frame:
player:update()
if player:pressed('jump') then ... end
if player:down('left') then ... end
local x, y = player:get('move')  -- for axis pairs
local device = player:getActiveDevice()  -- 'kbm', 'joy', or 'none'
```

### Runtime Rebinding

```lua
-- Source: baton API (verified)
-- Rebind jump to also include 'w' key
player.config.controls.jump = { 'key:space', 'key:w', 'button:a' }
-- Takes effect on next player:update()
```

### Love2D Touch API

```lua
-- Source: love2d.org/wiki/love.touch (verified via WebSearch)

-- Polling approach (called from plugin:update)
local touches = love.touch.getTouches()  -- returns table of lightuserdata IDs
for _, id in ipairs(touches) do
    local x, y = love.touch.getPosition(id)
    -- hit-test against regions
end

-- Callback approach (preferred for pressed/released transitions)
function love.touchpressed(id, x, y, dx, dy, pressure)
    -- id is lightuserdata — use as table key directly
    plugin._touch_regions:on_touch_pressed(id, x, y)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    plugin._touch_regions:on_touch_released(id, x, y)
end
```

### Percentage-Based Touch Region Resolution

```lua
-- Resolve a touch region rect to screen pixels
local function resolve_rect(region)
    if region.unit == "pct" then
        local sw, sh = love.graphics.getDimensions()
        return region.x * sw, region.y * sh, region.w * sw, region.h * sh
    else
        -- "px" or default
        return region.x, region.y, region.w, region.h
    end
end
```

### Plugin Registration in plugin_list.lua

```lua
-- src/core/plugin_list.lua
return {
    {
        name   = "input",
        module = "src.plugins.input",
        deps   = {},
    },
}
```

### Harness-Based Test Pattern

```lua
-- tests/plugins/input/input_plugin_spec.lua
local harness = require("tests.helpers.plugin_harness")
local InputPlugin = require("src.plugins.input")

describe("InputPlugin", function()
    local ctx

    before_each(function()
        ctx = harness.create_context({
            config = {
                input = {
                    jump = { key = 'space', gamepad = 'a' },
                },
            },
        })
        -- Reset plugin singleton state
        InputPlugin._player = nil
        InputPlugin._touch_regions = nil
        InputPlugin._bus = nil
    end)

    it("init succeeds without error", function()
        assert.has_no_error(function()
            InputPlugin:init(ctx)
        end)
    end)

    it("registers 'input' service", function()
        InputPlugin:init(ctx)
        assert.is_not_nil(ctx.services:get("input"))
    end)

    it("is_pressed returns true when mock player reports pressed", function()
        InputPlugin:init(ctx)
        -- Inject mock player state
        InputPlugin._player = {
            update = function() end,
            pressed = function(_, a) return a == "jump" end,
            down    = function() return false end,
            released = function() return false end,
            get     = function() return 0 end,
            getActiveDevice = function() return "kbm" end,
            config = { controls = {}, joystick = nil },
        }
        InputPlugin:update(0)
        local svc = ctx.services:get("input")
        assert.is_true(svc.is_pressed("jump"))
    end)
end)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Polling `love.keyboard.isDown()` directly in game code | Action-based abstraction (baton) | Ongoing since ~2016 | Device-agnostic game code |
| Single joystick assumption at startup | `love.joystickadded` hot-plug | Love2D 0.9.0 | Gamepad connect/disconnect handled at runtime |
| Separate keyboard/gamepad/touch code paths | Unified service API | This phase | Game code never touches device specifics |

**Deprecated/outdated:**
- `love.joystick.open(index)` — deprecated in favor of `love.joystickadded` callback which provides the joystick object directly. Do not use index-based joystick opening.

---

## Open Questions

1. **Registry update_all() method**
   - What we know: The current registry boots and shuts down plugins. It has no `update_all()` method.
   - What's unclear: Should `update_all()` be added to the registry, or should `main.lua` maintain its own list of update-capable plugins?
   - Recommendation: Add `Registry:update_all(dt)` that iterates registered plugins and calls `plugin:update(dt)` if the method exists. This is the cleanest architectural approach and `main.lua` can remain thin. This becomes a task in this phase's plan.

2. **main.lua touch callback wiring**
   - What we know: `love.touchpressed` / `love.touchreleased` must forward to the plugin. The CONTEXT.md mentions gamepad callbacks in main.lua but not touch callbacks explicitly.
   - What's unclear: Whether touch callbacks should be wired the same way as gamepad (explicit callbacks in main.lua) or through a different mechanism.
   - Recommendation: Wire touch callbacks identically to gamepad callbacks — thin pass-throughs in `main.lua` forwarding to the plugin's handler methods. This keeps the pattern consistent.

3. **Axis pair configuration**
   - What we know: Baton supports `pairs` for grouping four controls into a 2D axis (e.g., WASD → move). `get_axis(action)` is in the locked API.
   - What's unclear: Whether `get_axis` returns a single float (for 1D axis like triggers) or two floats (for 2D movement). Baton returns two values for pairs.
   - Recommendation: `get_axis(action)` returns `player:get(action)` which returns `x, y` for pairs and `value` for single controls. Document this dual-return in the service API. Tests should cover both cases.

---

## Sources

### Primary (HIGH confidence)
- baton.lua source fetched directly from GitHub tesselode/baton — API verified: `baton.new()`, `update()`, `down()`, `pressed()`, `released()`, `getActiveDevice()`, `player.config` runtime rebinding
- Love2D touch API — `love.touch.getTouches()`, `love.touchpressed(id, x, y, dx, dy, pressure)`, `love.touchreleased(id, x, y, dx, dy, pressure)` — verified via official wiki search
- Love2D joystick callbacks — `love.joystickadded(joystick)`, `love.joystickremoved(joystick)` — verified, fires at startup for already-connected controllers
- Existing codebase — `examples/canonical_plugin.lua`, `tests/helpers/plugin_harness.lua`, `src/core/context.lua`, `main.lua` — all read directly

### Secondary (MEDIUM confidence)
- Baton README structure (WebFetch of raw README) — configuration format and runtime rebinding pattern cross-verified against source code
- Love2D community forum patterns for gamepad hot-plug integration (confirmed via joystickadded/joystickremoved wiki pages)

### Tertiary (LOW confidence)
- None — all critical claims are verified at HIGH or MEDIUM level.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — baton API verified from source; Love2D touch API verified from official docs search
- Architecture: HIGH — patterns derived from existing codebase (canonical_plugin, harness) + verified baton API
- Pitfalls: HIGH — registry update gap is confirmed by reading main.lua; touch ID reuse is documented behavior in Love2D wiki; bus ordering is confirmed by reading bus.lua

**Research date:** 2026-03-02
**Valid until:** 2026-09-02 (baton is stable at v1.0.2; Love2D touch API is stable)
