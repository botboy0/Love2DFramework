---
phase: 03-input-plugin
plan: 02
subsystem: input
tags: [baton, love2d, touch, gamepad, keyboard, ecs, plugin, bus-events]

# Dependency graph
requires:
  - phase: 03-01
    provides: Registry:update_all(dt) and baton vendored at lib/baton.lua
  - phase: 02-plugin-infrastructure
    provides: plugin harness, canonical plugin pattern, service registration API

provides:
  - "Input plugin with unified keyboard/gamepad/touch input via baton"
  - "Touch region tracker with px/pct units and frame transitions"
  - "Service API: is_down, is_pressed, is_released, get_axis, get_active_device, get_touch_points, get_touch_regions"
  - "Bus events: input:action_pressed, input:action_released, input:device_changed, input:gamepad_connected, input:gamepad_disconnected"
  - "main.lua love.joystickadded/removed and love.touchpressed/released callbacks"
  - "plugin_list.lua boot manifest with input plugin registered"

affects:
  - 03-03
  - any phase that reads input state or responds to gamepad/touch events

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Service methods as plain functions (not :methods) so callers use svc.is_down('jump') not svc:is_down('jump')"
    - "Touch region hit test: x >= rx and x < rx + rw (exclusive right/bottom edge)"
    - "Percentage-based regions injected with opts = { screen_w, screen_h } to avoid love.graphics in tests"
    - "OR logic for unified baton+touch state: player:down(action) or touch_regions:down(action)"
    - ".busted lpath = './?/init.lua' — required for require('src.plugins.X') to find plugin init.lua"

key-files:
  created:
    - src/plugins/input/init.lua
    - src/plugins/input/touch_regions.lua
    - tests/plugins/input/init_spec.lua
    - tests/plugins/input/touch_regions_spec.lua
  modified:
    - src/core/plugin_list.lua
    - main.lua
    - .busted
    - tests/core/plugin_list_spec.lua
    - tests/core/registry_spec.lua

key-decisions:
  - "Service functions are plain functions (not methods) — callers use svc.is_down('jump') without colon"
  - "touch_regions.lua uses _get_dimensions() injection for test isolation (no love.graphics in tests)"
  - ".busted lpath = './?/init.lua' added to allow require('src.plugins.X') to resolve plugin init.lua files"
  - "love.touch nil-guarded in get_touch_points — love global may not exist in test environment"
  - "plugin_list and registry specs updated from 'starts empty' to 'contains input plugin' — placeholder tests replaced with actuals"

patterns-established:
  - "Input plugin pattern: ctx.config.input table drives baton config + touch regions in one pass"
  - "Plugin directory with init.lua requires .busted lpath entry for Lua to find init.lua via require()"

requirements-completed: [INPT-01, INPT-02, INPT-03]

# Metrics
duration: 6min
completed: 2026-03-02
---

# Phase 03 Plan 02: Input Plugin Summary

**Unified keyboard/gamepad/touch input via baton + TouchRegions with service API, bus events, and main.lua callback wiring**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-03-02T01:22:35Z
- **Completed:** 2026-03-02T01:28:30Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Input plugin with full baton integration: keyboard/gamepad action translation, pressed/down/released polling, axis reading
- TouchRegions module with hit testing (px and pct units), multi-touch tracking, and per-frame state transitions
- Service "input" registered with 7 query methods; discrete actions emit 5 bus event types
- main.lua wired with love.joystickadded/removed and love.touchpressed/released callbacks (nil-guarded)
- plugin_list.lua boots the input plugin via the standard registry boot path

## Task Commits

1. **RED: Failing tests** - `3ad9fae` (test)
2. **GREEN: touch_regions + init.lua implementation** - `55e08a3` (feat)
3. **Task 2: main.lua + plugin_list wiring** - `9f61e2a` (feat)

## Files Created/Modified

- `src/plugins/input/init.lua` - Input plugin: baton integration, service registration, bus events, joystick/touch forwarding
- `src/plugins/input/touch_regions.lua` - Touch region state tracker with px/pct hit testing and frame transitions
- `tests/plugins/input/init_spec.lua` - 31 tests: plugin lifecycle, service API, bus events, joystick and touch handlers
- `tests/plugins/input/touch_regions_spec.lua` - 21 tests: config parsing, hit testing, frame transitions, pct regions
- `src/core/plugin_list.lua` - Input plugin registered as first boot manifest entry
- `main.lua` - Added love.joystickadded/removed and love.touchpressed/released callbacks + _input_plugin local
- `.busted` - Added lpath = './?/init.lua' to enable require('src.plugins.X') finding plugin init.lua files
- `tests/core/plugin_list_spec.lua` - Updated stale 'starts empty' test to 'contains input plugin'
- `tests/core/registry_spec.lua` - Updated stale 'starts empty' test to match Phase 3 state

## Decisions Made

- Service functions are plain functions (not :methods). Callers use `svc.is_down("jump")` not `svc:is_down("jump")`. This matches canonical_query pattern from canonical_plugin.
- `_get_dimensions()` injected via opts for test isolation — avoids love.graphics dependency in tests. In production, defaults to `love.graphics.getDimensions`.
- `.busted` needed `lpath = './?/init.lua'` — Lua's default path doesn't include `./?/init.lua`, so `require("src.plugins.input")` couldn't resolve the directory-based plugin. This only affects directory-based plugins (flat files work fine with `./?.lua`).
- `love` and `love.touch` guarded against nil — test environment has no `love` global, so `get_touch_points` returns `{}` safely.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added ./?/init.lua to .busted lpath**
- **Found during:** Task 1 (GREEN phase — running tests after writing source)
- **Issue:** `require("src.plugins.input")` failed because Lua package.path lacks `./?/init.lua`. Directory-based plugins (with init.lua) can't be found without it.
- **Fix:** Added `lpath = "./?/init.lua"` to `.busted` config
- **Files modified:** `.busted`
- **Verification:** Full test suite passes (287/287)
- **Committed in:** 55e08a3

**2. [Rule 1 - Bug] Fixed service function signatures (plain functions not methods)**
- **Found during:** Task 1 (GREEN phase — service API tests failing)
- **Issue:** Service functions had `_svc` as first arg, but callers invoke `svc.is_down("jump")` (not `svc:is_down("jump")`), causing action arg to land in `_svc` slot
- **Fix:** Removed `_svc` parameter from all service functions; they are closures over `self` (InputPlugin)
- **Files modified:** `src/plugins/input/init.lua`
- **Verification:** All 31 init plugin tests pass
- **Committed in:** 55e08a3

**3. [Rule 1 - Bug] Updated stale plugin_list and registry specs**
- **Found during:** Task 2 (full test suite after plugin_list update)
- **Issue:** Existing tests asserting `plugin_list` is empty broke when input plugin was added — they were placeholder tests for "until Phase 3"
- **Fix:** Updated both specs to assert `#list == 1` and `list[1].name == "input"`
- **Files modified:** `tests/core/plugin_list_spec.lua`, `tests/core/registry_spec.lua`
- **Verification:** 287/287 tests pass
- **Committed in:** 9f61e2a

---

**Total deviations:** 3 auto-fixed (1 blocking, 2 bugs)
**Impact on plan:** All auto-fixes necessary for correctness. No scope creep.

## Issues Encountered

None beyond the three auto-fixed deviations above.

## Next Phase Readiness

- Input plugin boots via standard lifecycle; game code can query `ctx.services:get("input")` for unified input state
- Bus events ready for any system that needs to react to input transitions (e.g., UI, animation)
- Phase 03-03 can add input config to `_config` in main.lua and immediately use the service

---
*Phase: 03-input-plugin*
*Completed: 2026-03-02*
