---
phase: 04-asset-pipeline
plan: "03"
subsystem: asset-pipeline
tags: [plugin, assets, lily, atlas, service-api, tdd]
dependency_graph:
  requires:
    - 04-01  # Manifest, DrawableWrapper
    - 04-02  # AssetLoader, AtlasBuilder
  provides:
    - AssetPlugin (src.plugins.assets)
    - "assets" service (get/get_atlas/is_ready)
  affects:
    - src/core/plugin_list.lua (boot manifest)
tech_stack:
  added: []
  patterns:
    - TDD (RED-GREEN: init_spec.lua before init.lua)
    - Dependency injection via opts table (same as touch_regions.lua pattern)
    - Deferred bus emit to avoid re-entrancy (pending_ready flag, emitted in update())
    - Service functions as plain closures (not :methods), consistent with input plugin
key_files:
  created:
    - src/plugins/assets/init.lua
    - tests/plugins/assets/init_spec.lua
  modified:
    - src/core/plugin_list.lua
    - tests/core/plugin_list_spec.lua
    - tests/core/registry_spec.lua
    - scripts/validate_architecture.lua
decisions:
  - "Deferred asset:ready emission to update() to avoid bus re-entrancy guard — batch_complete handler fires during flush(), direct emit would be discarded"
  - "DI via second opts arg to init() — same pattern as touch_regions.lua _get_dimensions injection"
  - "Manifest.parse called with dot notation (Manifest.parse(tbl)) consistent with real module interface"
  - "block_depth replaces function_depth in validator detect_globals — counts ALL block-opening keywords to avoid premature decrement from nested if/for/while"
metrics:
  duration: "~6 min"
  completed: "2026-03-02"
  tasks_completed: 2
  files_created: 2
  files_modified: 4
requirements:
  - ASST-01
  - ASST-02
  - ASST-03
  - ASST-04
---

# Phase 4 Plan 03: Asset Plugin Integration Summary

Asset plugin init.lua that wires the load-then-pack pipeline (AssetLoader + AtlasBuilder + DrawableWrapper) into the standard plugin lifecycle, registers the "assets" service, and adds the plugin to the boot manifest.

## What Was Built

### src/plugins/assets/init.lua
Full-lifecycle asset plugin following the input plugin pattern exactly:
- `AssetPlugin.name = "assets"`, `AssetPlugin.deps = {}`
- `init(ctx, opts)` parses manifest, creates AssetLoader and AtlasBuilder with DI support, subscribes to `asset:batch_complete`, starts async load, registers service
- `_on_batch_complete()` runs atlas packing, wraps standalone assets, sets `_pending_ready`
- `update(_dt)` calls `loader:update()` and emits deferred `asset:ready` if pending
- `shutdown(_ctx)` calls `loader:shutdown()`
- Service API: `get(key)`, `get_atlas(group_name)`, `is_ready()`

### tests/plugins/assets/init_spec.lua
21 tests covering the full plugin lifecycle and service API, using plugin_harness with injected stubs for AssetLoader, AtlasBuilder, Manifest, and DrawableWrapper. Key scenarios:
- Plugin metadata (name, deps)
- `init()` calls Manifest.parse, starts load_manifest, registers "assets" service
- `update()` delegates to loader
- `batch_complete` pipeline: atlas builder called, atlas wrappers collected, standalone wrappers created
- `asset:ready` emitted after update() (deferred, not in flush cycle)
- `get()` strict mode errors, tolerant mode returns nil, fallback wrapper support
- `get_atlas()` delegation and nil for missing groups
- `is_ready()` false before, true after batch_complete
- `shutdown()` delegates to loader

### src/core/plugin_list.lua
Added `{ name = "assets", module = "src.plugins.assets", deps = {} }` after the input plugin entry.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed bus re-entrancy for asset:ready emission**
- **Found during:** Task 1 (TDD GREEN) — `asset:ready` emitted inside `asset:batch_complete` handler during bus flush, triggering re-entrancy guard (silently discarded)
- **Issue:** `_on_batch_complete()` called `self._bus:emit("asset:ready", {})` inside a bus `on()` handler which fires during `bus:flush()`. The bus re-entrancy guard discards emits during flush.
- **Fix:** Added `self._pending_ready = true` flag in `_on_batch_complete()`, emitted in next `update()` call after loader polls. Test helper updated to call `plugin:update(0)` + `ctx.bus:flush()` after firing batch_complete.
- **Files modified:** `src/plugins/assets/init.lua`, `tests/plugins/assets/init_spec.lua`
- **Commits:** 9466b0d

**2. [Rule 1 - Bug] Fixed validate_architecture.lua block depth tracking false positives**
- **Found during:** Task 1 verification — `lua scripts/validate_architecture.lua` reported 5 spurious "undeclared global" violations in `atlas_builder.lua` and `manifest.lua` (both from phases 04-01/04-02)
- **Issue:** `detect_globals()` used `function_depth` counter that decremented on ALL `end` keywords (including `if/for/while` block `end`s). After enough nested blocks inside a function, `function_depth` prematurely reached 0, causing assignments inside functions to be flagged as top-level globals.
- **Fix:** Replaced `function_depth` with `block_depth` that counts ALL block-opening keywords (`function`, `if`, `for`, `while`, `repeat`, standalone `do`) and decrements on `end`/`until`. This accurately tracks nesting depth regardless of block type.
- **Files modified:** `scripts/validate_architecture.lua`
- **Commit:** 9466b0d

**3. [Rule 1 - Bug] Fixed registry_spec.lua plugin count assertion**
- **Found during:** Task 2 full test suite run — `registry_spec.lua` hard-coded `assert.are.equal(1, #list)` expecting only the input plugin
- **Issue:** Adding assets plugin to plugin_list.lua broke this assertion
- **Fix:** Split into two tests: one checks input is first entry, one checks count is 2 (with Phase 4+ annotation)
- **Files modified:** `tests/core/registry_spec.lua`
- **Commit:** 8ab301b

## Key Decisions Made

1. **Deferred asset:ready emission**: `_on_batch_complete()` sets `_pending_ready = true` instead of directly emitting. The `update()` method checks and emits after the flush cycle. This avoids the bus re-entrancy guard that silently discards emits during flush.

2. **DI via second opts arg**: `init(ctx, opts)` accepts `{ _manifest, _asset_loader_new, _atlas_builder_new, _drawable_wrapper }` for test injection. Mirrors the `_get_dimensions` injection pattern from `touch_regions.lua`.

3. **block_depth replaces function_depth in validator**: The prior `function_depth` heuristic only tracked function boundaries but decremented on ALL `end` keywords. `block_depth` counts ALL Lua block-opening constructs, providing accurate top-level scope detection.

## Verification Results

| Check | Status |
|-------|--------|
| `busted tests/plugins/assets/init_spec.lua` | 21/21 pass |
| `busted` (full suite) | 379/379 pass |
| `selene src/ main.lua conf.lua` | 0 errors, 0 warnings |
| `stylua --check src/ main.lua conf.lua` | Clean |
| `lua scripts/validate_architecture.lua` | No violations |
| No `evolved.*` calls in assets plugin | Confirmed (ASST-04) |
| Bus events emitted only outside flush cycle | Confirmed (deferred pattern) |

## Self-Check: PASSED

All created files exist on disk. All task commits verified in git log.

| Item | Status |
|------|--------|
| `src/plugins/assets/init.lua` | FOUND |
| `tests/plugins/assets/init_spec.lua` | FOUND |
| `src/core/plugin_list.lua` | FOUND |
| Commit dd9ec74 (TDD RED) | FOUND |
| Commit 9466b0d (TDD GREEN + validator fix) | FOUND |
| Commit 8ab301b (Task 2 + registry fix) | FOUND |
