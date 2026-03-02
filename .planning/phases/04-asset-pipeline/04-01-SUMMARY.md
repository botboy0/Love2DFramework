---
phase: 04-asset-pipeline
plan: 01
subsystem: assets
tags: [lily, runtime-texture-atlas, love2d, manifest-parser, drawable-wrapper, vendoring]

requires: []

provides:
  - lib/lily.lua vendored (MikuAuahDark/lily async loader)
  - lib/TA.lua re-export + lib/RuntimeTextureAtlas/ vendored (EngineerSmith/Runtime-TextureAtlas)
  - Manifest.parse() converting config manifest table into typed load requests and atlas group map
  - DrawableWrapper: uniform draw(x,y,r,sx,sy) API for both atlas-backed and standalone assets
  - 31 passing tests covering all behaviors for both modules

affects: [04-02-asset-loader, 04-03-atlas-builder, 04-04-asset-plugin]

tech-stack:
  added:
    - lily (MikuAuahDark/lily) — Love2D async asset loader, vendored as lib/lily.lua
    - Runtime-TextureAtlas (EngineerSmith) — Love2D atlas packer, vendored as lib/RuntimeTextureAtlas/ with lib/TA.lua re-export
  patterns:
    - Dependency injection via opts table for all love.graphics calls (draw_fn, get_dimensions_fn)
    - TDD red-green cycle for pure-Lua modules testable without Love2D runtime

key-files:
  created:
    - lib/lily.lua
    - lib/TA.lua
    - lib/RuntimeTextureAtlas/init.lua
    - lib/RuntimeTextureAtlas/baseAtlas.lua
    - lib/RuntimeTextureAtlas/dynamicSize.lua
    - lib/RuntimeTextureAtlas/fixedSize.lua
    - lib/RuntimeTextureAtlas/packing.lua
    - lib/RuntimeTextureAtlas/util.lua
    - src/plugins/assets/manifest.lua
    - src/plugins/assets/drawable_wrapper.lua
    - tests/plugins/assets/manifest_spec.lua
    - tests/plugins/assets/drawable_wrapper_spec.lua
  modified: []

key-decisions:
  - "RTA is multi-file: vendored to lib/RuntimeTextureAtlas/ with lib/TA.lua as re-export wrapper (require('lib.TA'))"
  - "Manifest.parse returns (load_requests, groups) tuple — groups maps group_name -> [keys] for atlas-eligible images only"
  - "Image group derivation: atlas=false -> nil (standalone), explicit group= -> override, else derive from penultimate path segment"
  - "DrawableWrapper injectable via opts.draw_fn and opts.get_dimensions_fn — no love.graphics at module load time"
  - "Spy helper in tests uses setmetatable __call (not bare function) to allow field assignment in Lua 5.1"

patterns-established:
  - "Manifest parser: pure Lua, no Love2D dependency, returns typed structs"
  - "DrawableWrapper: opts table injection pattern for all Love2D calls (extends touch_regions.lua pattern)"
  - "Test spy: setmetatable with __call + fields rather than bare function"

requirements-completed: [ASST-02, ASST-03]

duration: 4min
completed: 2026-03-02
---

# Phase 04 Plan 01: Vendor Lily + RTA, Manifest Parser, DrawableWrapper Summary

**Lily and Runtime-TextureAtlas vendored in lib/, Manifest.parse() converts asset config to typed load requests with atlas group derivation, DrawableWrapper provides uniform draw(x,y,r,sx,sy) API for both atlas and standalone assets — all injectable and testable without Love2D runtime.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-02T02:39:14Z
- **Completed:** 2026-03-02T02:42:42Z
- **Tasks:** 2
- **Files modified:** 12 (10 created, 2 test files)

## Accomplishments

- Vendored Lily (single-file async loader) and Runtime-TextureAtlas (6-file multi-module packer) into lib/
- Implemented Manifest.parse() with full group assignment logic: standalone (atlas=false), explicit group, and directory-derived group
- Implemented DrawableWrapper with two construction paths (atlas/standalone) and fully injectable Love2D calls
- 31 passing tests (17 manifest + 14 drawable_wrapper), selene and stylua clean

## Task Commits

Each task was committed atomically:

1. **Task 1: Vendor Lily + RTA and implement manifest parser** - `cd9693c` (feat)
2. **Task 2: Implement drawable wrapper with uniform API** - `388e887` (feat)

## Files Created/Modified

- `lib/lily.lua` - Vendored Lily async loader (MikuAuahDark/lily)
- `lib/TA.lua` - Re-export wrapper for Runtime-TextureAtlas
- `lib/RuntimeTextureAtlas/` - Vendored RTA (6 files: init, baseAtlas, dynamicSize, fixedSize, packing, util)
- `src/plugins/assets/manifest.lua` - Manifest.parse() with image group derivation, font/sound extras, error on unknown type
- `src/plugins/assets/drawable_wrapper.lua` - DrawableWrapper with atlas and standalone paths, dependency-injectable draw_fn
- `tests/plugins/assets/manifest_spec.lua` - 17 tests covering all manifest parsing behaviors
- `tests/plugins/assets/drawable_wrapper_spec.lua` - 14 tests covering all DrawableWrapper methods for both types

## Decisions Made

- RTA is multi-file (not a single lua file): vendored to `lib/RuntimeTextureAtlas/` with `lib/TA.lua` as a simple `require("lib.RuntimeTextureAtlas")` re-export. This mirrors how the library uses `...` for require paths.
- DrawableWrapper stores `_draw_fn` with a lazy default closure (calls `love.graphics.draw(...)` at call time, not at module load) — avoids requiring `love` during `require("src.plugins.assets.drawable_wrapper")` in tests.
- Test spy helper uses `setmetatable({}, { __call = ... })` instead of a bare function table so Lua 5.1 allows field assignment. Documented in key-decisions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed make_spy helper in drawable_wrapper_spec.lua**
- **Found during:** Task 2 (DrawableWrapper implementation)
- **Issue:** Test helper created a bare function and tried to set fields on it (`fn.calls = calls`) — Lua does not allow field access on bare functions; causes "attempt to index local 'fn' (a function value)"
- **Fix:** Changed spy to `setmetatable({}, { __call = function(...) end })` pattern so fields can be set while the value remains callable
- **Files modified:** `tests/plugins/assets/drawable_wrapper_spec.lua`
- **Verification:** 14 tests pass after fix; zero errors
- **Committed in:** `388e887` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug in test helper)
**Impact on plan:** Minor test code fix. No scope creep. Implementation unchanged.

## Issues Encountered

- Runtime-TextureAtlas is not a single-file library (unlike Lily). Repository has 6 Lua files using `...` relative require paths. Resolution: vendor all 6 files into `lib/RuntimeTextureAtlas/` and create `lib/TA.lua` as a re-export. Works correctly since RTA uses `require(... .. ".fixedSize")` pattern which resolves against the module path.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `lib/lily.lua` and `lib/TA.lua` available for asset_loader.lua and atlas_builder.lua
- `Manifest.parse()` data contract established — load_requests and groups types are fixed
- `DrawableWrapper` API established — later phases return wrappers from `assets:get(key)`
- No blockers for plan 04-02 (asset loader) or 04-03 (atlas builder)

---
*Phase: 04-asset-pipeline*
*Completed: 2026-03-02*
