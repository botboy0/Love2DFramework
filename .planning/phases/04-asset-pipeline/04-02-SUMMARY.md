---
phase: 04-asset-pipeline
plan: 02
subsystem: assets
tags: [lily, runtime-texture-atlas, async-loading, texture-atlas, drawable-wrapper, dependency-injection]

requires:
  - phase: 04-01
    provides: "lib/lily.lua and lib/TA.lua vendored, Manifest.parse() data contract, DrawableWrapper.from_atlas() API"

provides:
  - AssetLoader: Lily wrapper with manual update mode, bus-event-only callbacks, strict/tolerant error modes
  - AtlasBuilder: RTA wrapper with 4096 cap enforcement, auto-split greedy algorithm, DrawableWrapper creation
  - 35 passing tests (20 asset_loader + 15 atlas_builder) using injectable stubs

affects: [04-03-asset-plugin, 04-04-asset-plugin]

tech-stack:
  added: []
  patterns:
    - "Lily manual update mode: setUpdateMode('manual') called in constructor so callbacks fire only when update() is called each frame"
    - "Bus-event-only callbacks: no ECS calls (evolved.spawn/id) anywhere in asset modules — ASST-04 architecture rule enforced"
    - "Dependency injection continued: lily, love_graphics, drawable_wrapper, log all injectable via opts table"
    - "Auto-split via greedy descending-area bin-fill: sort images by area desc, fill sub-groups greedily to stay within budget"

key-files:
  created:
    - src/plugins/assets/asset_loader.lua
    - src/plugins/assets/atlas_builder.lua
    - tests/plugins/assets/asset_loader_spec.lua
    - tests/plugins/assets/atlas_builder_spec.lua
  modified: []

key-decisions:
  - "AssetLoader uses loadMulti for both load_manifest and load_single — consistent callback interface, simpler pending tracking"
  - "is_complete() tracks _manifest_complete boolean (set in onComplete) and _pending_singles counter — clear state model"
  - "AtlasBuilder canvas retrieval: try atlas:getCanvas() first, fall back to atlas._canvas field (handles both real RTA and stubs)"
  - "Auto-split algorithm: greedy descending-area bin-fill produces sub-groups named group_1, group_2, etc."
  - "AtlasBuilder injects drawable_wrapper module (not just the function) so tests can pass the real DrawableWrapper"

patterns-established:
  - "Lily stub pattern: loadMulti returns handle with _simulate_complete() / _simulate_error() helpers for synchronous test control"
  - "RTA stub pattern: newDynamicSize returns atlas with deterministic getViewport() returning fixed 0,0,32,32 for all keys"
  - "Bus event verification: collect_events() helper subscribes before triggering callbacks, then flush() dispatches to verify payloads"

requirements-completed: [ASST-01, ASST-03, ASST-04]

duration: 3min
completed: 2026-03-02
---

# Phase 04 Plan 02: AssetLoader and AtlasBuilder Summary

**Lily-based async asset loader with bus-event-only callbacks and RTA-based atlas packer with greedy auto-split — both fully testable via dependency injection without Love2D runtime.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-02T02:45:21Z
- **Completed:** 2026-03-02T02:48:36Z
- **Tasks:** 2 (TDD — each with RED + GREEN commits)
- **Files modified:** 4 created

## Accomplishments

- Implemented AssetLoader wrapping Lily with manual update mode — asset I/O never blocks the main thread (ASST-01)
- All Lily callbacks emit bus events only (`asset:loaded`, `asset:batch_complete`) — zero ECS mutations in asset modules (ASST-04)
- Implemented AtlasBuilder with 4096x4096 cap and automatic group splitting with greedy descending-area bin-fill (ASST-03)
- 35 passing tests covering all behaviors; both modules injectable without Love2D runtime

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement asset loader with Lily dependency injection** - `d034da6` (feat)
2. **Task 2: Implement atlas builder with 4096 cap and auto-split** - `23ea971` (feat)

## Files Created/Modified

- `src/plugins/assets/asset_loader.lua` - Lily wrapper: load_manifest, load_single, update, is_complete, get_loaded, shutdown
- `src/plugins/assets/atlas_builder.lua` - RTA wrapper: build, auto-split, _pack_atlas, get_atlas, get_all_atlases
- `tests/plugins/assets/asset_loader_spec.lua` - 20 tests with Lily stub and real Bus
- `tests/plugins/assets/atlas_builder_spec.lua` - 15 tests with RTA stub and love.graphics stub

## Decisions Made

- `AssetLoader` uses `loadMulti` for both `load_manifest` and `load_single`. Reusing the same multi-handle API simplifies the callback interface and keeps pending-load tracking uniform (a single counter for singles, a boolean for the manifest batch).
- `is_complete()` uses two fields: `_manifest_complete` (boolean set in `onComplete`) and `_pending_singles` (counter decremented on each single's `onComplete`). Simple and predictable.
- `AtlasBuilder` canvas retrieval tries `atlas:getCanvas()` first then falls back to `atlas._canvas`. This tolerates both the real RTA implementation and any stub that exposes the field directly.
- Auto-split sub-group naming: `group_1`, `group_2`, etc. Simple and unambiguous. Documented in warning message.
- `AtlasBuilder.new(opts)` injects the full `drawable_wrapper` module (not just `from_atlas`) so tests pass the real `DrawableWrapper` and the implementation uses `self._drawable_wrapper.from_atlas(...)`.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `AssetLoader` and `AtlasBuilder` are ready for integration in the assets plugin (`init.lua`)
- Both modules honour the Manifest.parse() data contract established in 04-01
- DrawableWrapper.from_atlas() is called correctly by AtlasBuilder — the atlas-backed wrapper API is exercised
- No blockers for plan 04-03 (asset plugin integration)

---
*Phase: 04-asset-pipeline*
*Completed: 2026-03-02*

## Self-Check: PASSED

- FOUND: src/plugins/assets/asset_loader.lua
- FOUND: src/plugins/assets/atlas_builder.lua
- FOUND: tests/plugins/assets/asset_loader_spec.lua
- FOUND: tests/plugins/assets/atlas_builder_spec.lua
- FOUND: .planning/phases/04-asset-pipeline/04-02-SUMMARY.md
- FOUND commit: d034da6 (Task 1)
- FOUND commit: 23ea971 (Task 2)
