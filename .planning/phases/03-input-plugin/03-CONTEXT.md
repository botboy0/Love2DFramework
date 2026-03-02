# Phase 3: Input Plugin - Context

**Gathered:** 2026-03-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Unified keyboard/gamepad/touch input via baton, registered as a standard framework plugin. Game code queries player input actions without knowing whether the source is keyboard, gamepad, or touch. Runtime rebinding is supported. The plugin follows the standard `plugin:init(ctx)` / `plugin:quit()` lifecycle.

</domain>

<decisions>
## Implementation Decisions

### Action mapping design
- Actions defined via `ctx.config.input` config table — follows established config pattern
- No default bindings — games must explicitly declare all actions
- Include commented-out examples in config section showing the table structure for developer guidance
- Multiple bindings per device supported via arrays (e.g., `{ key = {'space', 'w'}, gamepad = 'a' }`)
- Runtime rebinding supported — bindings can be changed after init (baton supports this natively)

### Input query API
- Hybrid model: intent events on the bus for discrete actions (jump, interact), polling via service for continuous axes (movement, aiming)
- Service exposes full state queries: `is_down(action)`, `is_pressed(action)` (just went down this frame), `is_released(action)` (just went up this frame), `get_axis(action)`
- Active device tracking: `get_active_device()` returns which device (keyboard/gamepad) was last used
- Plugin uses explicit `update(dt)` call — follows canonical plugin pattern, no Love2D callback hooks for update
- Love2D callbacks (`love.gamepadpressed`, `love.gamepadaxis`, etc.) forwarded as thin pass-throughs in main.lua for gamepad hot-plugging

### Touch input strategy
- Basic rectangular touch regions mapped to actions — digital on/off only (tap region = action pressed)
- Config supports `unit` field on touch regions: `"px"` (default if omitted) or `"pct"` (screen-relative percentage)
  - Pixels: `{ touch = { x = 0, y = 400, w = 120, h = 120 } }` or `{ touch = { x = 0, y = 400, w = 120, h = 120, unit = "px" } }`
  - Percentage: `{ touch = { x = 0, y = 0.8, w = 0.15, h = 0.15, unit = "pct" } }`
- Raw touch position accessor exposed via service (`get_touch_points()`) — for games that need to know where the user tapped, independent of action regions
- No gestures, virtual sticks, multi-touch combos, or analog touch axes — deferred
- No debug overlay for touch regions — visualization belongs in Phase 6 (Developer Tools)

### Bus event integration
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

</decisions>

<specifics>
## Specific Ideas

- Commented examples in config showing the full action map structure so developers aren't guessing
- Touch regions use explicit `unit` field rather than magic detection of pixels vs percentages
- Event payloads include device source so systems can react to input method without polling
- The plugin should expose `get_touch_regions()` on its service so Phase 6 dev tools can draw debug overlays later

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `examples/canonical_plugin.lua`: Reference template for plugin structure — init, update, shutdown, service registration, event subscription
- `src/core/context.lua` Services registry: `ctx.services:register()` / `ctx.services:get()` — the integration point for exposing input queries

### Established Patterns
- Config passed via `ctx.config` — input config fits naturally as `ctx.config.input`
- Plugin update via `plugin:update(dt)` called by game loop
- Event bus deferred dispatch — events queued during update, delivered on `bus:flush()`
- Service registration for cross-plugin queries (demonstrated in canonical plugin)

### Integration Points
- `src/core/plugin_list.lua`: Input plugin will be registered here
- `main.lua`: Thin Love2D callback pass-throughs needed for gamepad hot-plugging (`love.gamepadpressed`, etc.)
- `lib/`: Baton library will be vendored here
- `src/core/components.lua`: No input-specific ECS components anticipated (input is service-based, not entity-based)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-input-plugin*
*Context gathered: 2026-03-02*
