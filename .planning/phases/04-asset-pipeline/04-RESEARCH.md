# Phase 4: Asset Pipeline - Research

**Researched:** 2026-03-02
**Domain:** Async asset loading (Lily), texture atlas packing (Runtime-TextureAtlas), Love2D asset service architecture
**Confidence:** MEDIUM-HIGH (core library APIs verified via official GitHub; some integration patterns based on project conventions)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Loading Lifecycle**
- Load-then-pack pipeline: Lily loads all images async first, then Runtime-TextureAtlas packs them into atlases once all images are in memory. Two distinct phases.
- Both manifest-driven (startup batch) and on-demand (mid-game) loading supported
- Manifest defined in `ctx.config.assets` following the existing config-driven pattern (like `ctx.config.input`)
- Lily completion callbacks queue bus events (deferred dispatch naturally prevents mid-tick entity spawning)
- Three event granularities: `asset:loaded { key, type, path }` per-asset, `asset:batch_complete { keys }` per-batch, `asset:ready` when all manifest assets loaded and atlases packed
- Configurable loading phase via `ctx.config.assets.loading_phase` (default `true`) — when enabled, plugin tracks ready state, exposes `assets:is_ready()`, and emits `asset:ready`

**Asset API Surface**
- Service registered as `"assets"` via `ctx.services:register`
- Both service (direct access for fonts, sounds, non-entity assets) and ECS components (for entity-bound sprites resolved by render systems)
- Assets referenced by manifest logical keys, not file paths — decouples game code from file structure
- Manifest assets: `assets:get(key)` errors if asset not loaded (fail-fast — if loading phase completed, asset must exist)
- On-demand assets: `assets:get(key)` returns nil while loading in progress
- Atlas quads transparent by default — `assets:get("player_idle")` returns a drawable wrapper regardless of atlas vs standalone
- Explicit atlas access available for power users: `assets:get_atlas("characters")` for raw quad/texture access

**Atlas Packing Strategy**
- Directory-based group assignment by default (sprites in `assets/characters/` become the "characters" atlas)
- Manifest overrides to reassign specific sprites to custom groups
- One atlas per group for natural draw call batching
- Auto-split safety net: if a group exceeds 4096x4096, automatically split into multiple atlases
- Non-atlas sprites (backgrounds, large textures) load as standalone `love.graphics.Image` via Lily
- Atlases built once during loading phase and frozen — no runtime repacking (v1)

**Error Handling**
- Configurable `error_mode` (strict/tolerant) following existing framework pattern on bus and registry
- Strict mode (default): error and halt on any failed asset load
- Tolerant mode: log warning, skip failed asset — `assets:get(key)` returns nil for failed assets
- Optional fallback assets per type via `ctx.config.assets.fallbacks = { image = "path", font = "path", sound = "path" }` — used in tolerant mode instead of nil. If fallback itself fails to load, crash (broken configuration)
- Warning emitted on atlas auto-split: "Group 'X' split into N atlases (exceeded 4096x4096). Consider splitting into smaller groups."

**Asset Types (v1)**
- Images (`love.graphics.newImage`) — primary, atlas-eligible
- Fonts (`love.graphics.newFont`) — standalone, async via Lily
- Sounds (`love.audio.newSource`) — standalone, async via Lily

### Claude's Discretion

- Internal cache/storage structure for loaded assets
- Lily batch size and concurrency tuning
- Drawable wrapper implementation details
- Exact manifest config table schema (beyond the decisions captured here)
- Atlas packing algorithm parameters (padding, sorting)

### Deferred Ideas (OUT OF SCOPE)

- Runtime atlas repacking (dynamic atlas updates mid-game) — potential v2 feature
- Asset hot-swap / hot-reload — explicitly out of scope per REQUIREMENTS.md
- Data file loading (JSON, Lua tables) — beyond v1 asset types
- Compressed asset support — niche, future if needed
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ASST-01 | Async asset loading via Lily prevents frame hitches during loading | Lily `lily.loadMulti()` with `onComplete` callbacks run off-main-thread; `setUpdateMode("manual")` enables polling in plugin `update()` |
| ASST-02 | Texture atlas packing via Runtime-TextureAtlas at startup reduces draw calls | RTA `newDynamicSize()` + `bake()` consolidates images to single canvas; `getViewport()` returns quad coords; draw from one texture |
| ASST-03 | Asset pipeline capped at 4096x4096 atlas size for mobile GPU compatibility | RTA `setMaxSize(4096, 4096)` enforces limit; framework layer tracks group size and splits at boundary |
| ASST-04 | Lily callbacks emit bus events only — no direct entity spawning mid-tick | Lily `onComplete` queues `bus:emit()` which is deferred; bus re-entrancy guard prevents mid-flush mutations |
</phase_requirements>

---

## Summary

Phase 4 implements an asset service plugin using two vendored libraries: **Lily** for async I/O and **Runtime-TextureAtlas (RTA)** for startup atlas packing. The pipeline runs in two sequential phases: Lily loads raw image/font/sound files off the main thread, and once all files are in memory, RTA packs image groups into atlases on the main thread. The bus's deferred-dispatch model naturally satisfies ASST-04 — Lily completion callbacks call `bus:emit()`, which queues events for the next `bus:flush()` rather than firing handlers immediately.

The asset service exposes a uniform `assets:get(key)` API that returns a drawable wrapper regardless of whether the asset is atlas-packed or standalone. This keeps render systems decoupled from atlas internals. The 4096x4096 cap (ASST-03) is enforced via RTA's `setMaxSize()` combined with a framework-side auto-split that creates multiple atlases when a group would exceed the limit.

Testing the asset plugin requires careful architecture because `love.graphics.newImage`, `love.audio.newSource`, and Lily all require Love2D runtime context. The established project pattern (see `touch_regions.lua` with `_get_dimensions()` injection) is to abstract all Love2D calls behind injectable functions, enabling busted tests to run headlessly with stubs.

**Primary recommendation:** Vendor both Lily and Runtime-TextureAtlas into `lib/`, implement the asset plugin following the input plugin's pattern, and use dependency injection for all Love2D calls to keep tests headless.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Lily | latest (MikuAuahDark/lily) | Async asset loading off main thread | Only Love2D async loader with multi-thread support and clean callback API; listed in awesome-love2d |
| Runtime-TextureAtlas (RTA) | latest (EngineerSmith/Runtime-TextureAtlas) | Runtime texture atlas packing | No external tooling required; Love2D native canvas-based; supports dynamic-size packing with padding/spacing/extrude |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| love.graphics.newQuad | built-in | Create quads for atlas regions | Used internally by drawable wrapper — RTA's `getViewport()` returns x,y,w,h; we build quads from those |
| love.graphics.draw | built-in | Draw quad from atlas | Render systems call this with atlas texture + quad |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Runtime-TextureAtlas | love-loader | love-loader does async loading but no atlas packing; would need separate atlas library |
| Runtime-TextureAtlas (dynamic) | Runtime-TextureAtlas (fixed) | Fixed-size is faster but all sprites must be identical dimensions — not suitable for mixed sprite sizes |
| Lily | lua coroutine chunking | Coroutine approach avoids threading but blocks main thread for each load step; no true parallelism |

**Installation:** Both libraries are single-file (or small directory). Vendor by copying into `lib/lily.lua` and `lib/RuntimeTextureAtlas/` (or `lib/TA.lua`). No package manager needed — consistent with how baton, binser, and evolved are vendored.

---

## Architecture Patterns

### Recommended Project Structure

```
src/plugins/assets/
  init.lua               # Plugin entry: registers service, handles Lily polling
  asset_loader.lua       # Lily wrapper: loads assets, calls bus:emit on complete
  atlas_builder.lua      # RTA wrapper: groups images, packs atlases, returns atlas map
  drawable_wrapper.lua   # Uniform drawable: wraps (texture, quad) or standalone Image
  manifest.lua           # Parses ctx.config.assets into typed load requests

tests/plugins/assets/
  init_spec.lua
  asset_loader_spec.lua
  atlas_builder_spec.lua
  drawable_wrapper_spec.lua
  manifest_spec.lua
```

### Pattern 1: Lily Manual Update Mode for Plugin Integration

The asset plugin's `update(dt)` calls `lily.update()` manually. This gives the plugin control over when Lily polls thread results and fires callbacks.

**What:** Use `lily.setUpdateMode("manual")` in plugin `init()`, then call `lily.update()` in the plugin's `update(dt)` method. Callbacks fire synchronously within `lily.update()` on the main thread.

**When to use:** Always — automatic mode hooks into Love2D event handlers which is inappropriate in a plugin-based architecture where `love.update` delegates to the registry.

```lua
-- Source: https://github.com/MikuAuahDark/lily (README + lily.lua)

-- In AssetPlugin:init(ctx)
lily.setUpdateMode("manual")

-- Single asset load
local handle = lily.newImage("assets/sprites/player.png")
handle:onComplete(function(self, image)
  -- This runs on the main thread during lily.update() call
  -- Safe to call bus:emit() here — it queues, doesn't fire handlers
  ctx.bus:emit("asset:loaded", { key = "player_idle", type = "image", path = "..." })
  self._cache[key] = image
end)
handle:onError(function(self, msg, _trace)
  -- Handle per error_mode
end)

-- Multi asset load (preferred for manifest batches)
local multi = lily.loadMulti({
  { lily.newImage, "assets/sprites/player.png" },
  { lily.newImage, "assets/sprites/enemy.png"  },
  { lily.newFont,  "assets/fonts/ui.ttf", 16   },
})
multi:onLoaded(function(self, index, value)
  -- Fires per-item as each completes
  ctx.bus:emit("asset:loaded", { ... })
end)
multi:onComplete(function(self, all_values)
  -- Fires when ALL items in the batch are done
  ctx.bus:emit("asset:batch_complete", { keys = batch_keys })
end)

-- In AssetPlugin:update(dt)
lily.update()  -- Triggers any completed callbacks
```

### Pattern 2: Load-Then-Pack Pipeline

Images are collected during Lily's async phase. Atlas packing runs synchronously on the main thread AFTER all Lily loads complete.

```lua
-- In the batch onComplete callback — all images now in memory
local function pack_atlases(image_map)
  local TA = require("lib.TA")
  local groups = group_by_directory(image_map)  -- or manifest overrides

  local atlases = {}
  for group_name, images in pairs(groups) do
    local atlas = TA.newDynamicSize(1, 0, 1)  -- padding=1, extrude=0, spacing=1
    atlas:setMaxSize(4096, 4096)

    for key, img in pairs(images) do
      atlas:add(img, key)  -- id = logical key
    end

    local ok, err = pcall(function() atlas:bake("area") end)
    if not ok then
      -- Group likely exceeded 4096x4096 — implement auto-split
      handle_atlas_overflow(group_name, images, atlases)
    else
      atlases[group_name] = atlas
    end
  end
  return atlases
end
```

### Pattern 3: Drawable Wrapper (Uniform Asset API)

`assets:get(key)` always returns a drawable wrapper regardless of whether the asset is standalone or atlas-packed.

```lua
-- drawable_wrapper.lua
local DrawableWrapper = {}
DrawableWrapper.__index = DrawableWrapper

-- For atlas-packed sprites
function DrawableWrapper.from_atlas(atlas, id, atlas_texture)
  local x, y, w, h = atlas:getViewport(id)
  local quad = love.graphics.newQuad(x, y, w, h, atlas_texture:getDimensions())
  return setmetatable({
    _type    = "atlas",
    _texture = atlas_texture,
    _quad    = quad,
  }, DrawableWrapper)
end

-- For standalone images (fonts, sounds, backgrounds)
function DrawableWrapper.from_standalone(asset)
  return setmetatable({
    _type  = "standalone",
    _asset = asset,
  }, DrawableWrapper)
end

-- Uniform draw API
function DrawableWrapper:draw(x, y, r, sx, sy)
  if self._type == "atlas" then
    love.graphics.draw(self._texture, self._quad, x, y, r, sx, sy)
  else
    love.graphics.draw(self._asset, x, y, r, sx, sy)
  end
end
```

### Pattern 4: Dependency-Injected Love2D Calls (Testability)

Every module that calls `love.graphics.*`, `love.audio.*`, or `lily.*` must accept injectable overrides. This is the established project pattern from `touch_regions.lua`.

```lua
-- asset_loader.lua
local AssetLoader = {}

-- _lily and _love_graphics are injected — defaults to real libs
function AssetLoader.new(opts)
  opts = opts or {}
  return {
    _lily = opts.lily or require("lib.lily"),
    _love_graphics = opts.love_graphics or love.graphics,
    _love_audio = opts.love_audio or love.audio,
  }
end
```

In tests, pass stub implementations. Lily stub returns handles with no-op callbacks that can be triggered synchronously in tests.

### Anti-Patterns to Avoid

- **Calling `love.graphics.newImage()` in Lily callbacks:** `love.graphics.*` calls are main-thread-only in Love2D — but Lily callbacks DO fire on the main thread (during `lily.update()`), so this is actually safe. The trap is thinking you must defer to the next frame; you don't.
- **Packing atlases before all Lily loads complete:** RTA's `bake()` freezes the window. If called mid-load, some images are missing from the atlas and must be repacked later — defeating the "pack once" guarantee.
- **Using `lily.setUpdateMode("automatic")` in a plugin:** Automatic mode registers Love2D event handlers directly, bypassing the plugin registry's update loop.
- **Calling `bus:emit()` inside `bus:flush()`:** The bus re-entrancy guard discards any emits during flush. Lily callbacks run during `lily.update()` which is called from `plugin:update()` which runs before `bus:flush()` in `main.lua` — so this is naturally safe.
- **Storing file paths in game code instead of logical keys:** Breaks the manifest abstraction. All game code must use keys like `"player_idle"`, never `"assets/sprites/player_idle.png"`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async I/O off main thread | Thread + Channel + coroutine loop | Lily | Thread safety, cross-platform compatibility, CPU detection, teardown on quit |
| Bin-packing algorithm | Custom rectangle packing | RTA dynamic-size bake | Correct packing is NP-hard; RTA's cell algorithm is production-tested on Android/Love 11 |
| Quad extraction from atlas | Custom atlas metadata format | RTA `getViewport()` + `love.graphics.newQuad()` | RTA tracks positions internally after bake; no external JSON/XML needed |
| Thread-safe callback dispatch | love.Channel polling loop | Lily's built-in callback system | Lily handles thread synchronization and LOVE event integration internally |

**Key insight:** Both Lily and RTA were built specifically for Love2D's threading and graphics model. Hand-rolling either would require deep knowledge of Love2D's thread-channel system and OpenGL canvas constraints — complexity that belongs in a library.

---

## Common Pitfalls

### Pitfall 1: RTA `bake()` Freezes the Window

**What goes wrong:** Calling `atlas:bake()` synchronously on large groups (many sprites or high-res) stalls the render loop, causing a visible freeze/hitch.

**Why it happens:** RTA uses `love.graphics.Canvas` operations which are synchronous and block the main thread.

**How to avoid:** Bake once during an explicit loading phase, not during gameplay. The load-then-pack pipeline decision already addresses this — baking happens before `asset:ready` is emitted, before the game scene is shown.

**Warning signs:** Frame time spikes during level load; atlas size correlates with spike duration.

---

### Pitfall 2: Lily Callbacks Fire During `lily.update()` — Timing Matters

**What goes wrong:** Developer calls `lily.update()` inside a system's `update()` method late in the frame, after `bus:flush()` has already run. Lily callbacks emit events that won't be flushed until next frame, creating a one-frame lag.

**Why it happens:** Misunderstanding of when `lily.update()` must be called relative to `bus:flush()`.

**How to avoid:** Call `lily.update()` in the asset plugin's `update(dt)` BEFORE `bus:flush()`. The existing `main.lua` ordering (`registry:update_all(dt)` → `bus:flush()`) guarantees this naturally — plugin `update()` always runs before flush.

**Warning signs:** Events arrive one frame late; `asset:ready` fires on frame N+1 instead of N.

---

### Pitfall 3: Atlas Size Limit Requires Framework-Side Enforcement

**What goes wrong:** RTA's `setMaxSize(4096, 4096)` is NOT a hard guard that automatically splits groups. Calling `bake()` on a group that would exceed 4096x4096 may succeed (if the canvas driver allows larger) or fail with an opaque error.

**Why it happens:** RTA delegates to `love.graphics.newCanvas()` which has hardware-dependent limits. The `setMaxSize` affects internal layout decisions but is not guaranteed to error on overflow in all RTA versions.

**How to avoid:** The framework must pre-calculate group pixel area before calling `bake()`. If estimated area exceeds 4096×4096, split the group and emit the configured warning. Use `love.graphics.getMaxImageSize()` as a cross-check against the hardware cap.

**Warning signs:** Different behavior on desktop (high canvas limits) vs mobile (4096 cap); silent atlas truncation.

---

### Pitfall 4: `love.graphics.*` Unavailable Without a Window

**What goes wrong:** Tests that `require("lib.TA")` or call `love.graphics.newCanvas()` fail immediately in busted because no Love2D window/context exists.

**Why it happens:** Love2D's graphics module requires an OpenGL context, which requires a window. Busted runs outside Love2D's event loop.

**How to avoid:** Use dependency injection (Pattern 4 above) — all `love.graphics.*` calls are behind injectable functions. Test modules with stub implementations. `atlas_builder_spec.lua` injects a fake `love.graphics` table with no-op methods.

**Warning signs:** Tests pass in `love .` context but fail in `busted`; error messages mentioning OpenGL or missing window.

---

### Pitfall 5: Lily `quit()` Must Be Called on Shutdown

**What goes wrong:** On iOS/Android (and some desktop configurations), failing to call `lily.quit()` before the game exits causes thread cleanup errors or hangs.

**Why it happens:** Lily spawns worker threads that must be explicitly terminated.

**How to avoid:** Call `lily.quit()` in the asset plugin's `shutdown(ctx)` method. The registry calls `shutdown` in reverse boot order on `love.quit`.

**Warning signs:** Game hangs on exit; crash logs mentioning thread cleanup on mobile.

---

## Code Examples

Verified patterns from official sources and project conventions:

### Lily: Load Multiple Assets

```lua
-- Source: https://github.com/MikuAuahDark/lily (README)
local lily = require("lib.lily")
lily.setUpdateMode("manual")  -- Plugin controls polling

local multi = lily.loadMulti({
  { lily.newImage,  "assets/sprites/player.png" },
  { lily.newFont,   "assets/fonts/ui.ttf", 16   },
  { lily.newSource, "assets/sfx/jump.ogg", "static" },
})

multi:onLoaded(function(self, index, value)
  -- index: 1-based position in the loadMulti table
  -- value: the loaded Love2D object
  bus:emit("asset:loaded", { key = keys[index], type = types[index] })
end)

multi:onComplete(function(self, all_values)
  -- all_values: array matching loadMulti order
  bus:emit("asset:batch_complete", { keys = batch_keys })
end)

multi:onError(function(self, msg, trace)
  if error_mode == "strict" then
    error("[Assets] Load failed: " .. msg)
  else
    bus:emit("asset:load_failed", { error = msg })
  end
end)

-- In plugin update():
function AssetPlugin:update(_dt)
  lily.update()  -- Triggers completed callbacks synchronously
end

-- In plugin shutdown():
function AssetPlugin:shutdown(_ctx)
  lily.quit()
end
```

### RTA: Pack a Group into an Atlas

```lua
-- Source: https://github.com/EngineerSmith/Runtime-TextureAtlas (README)
local TA = require("lib.TA")

local atlas = TA.newDynamicSize(1, 0, 1)  -- padding=1, extrude=0, spacing=1
atlas:setMaxSize(4096, 4096)              -- Mobile-safe limit

for key, image in pairs(image_group) do
  atlas:add(image, key)  -- id = logical key string
end

atlas:bake("area")   -- Sort by area for best packing efficiency

-- Extract quads AFTER bake
local canvas = atlas._canvas  -- Internal canvas (check RTA source for public accessor)
for key, _ in pairs(image_group) do
  local x, y, w, h = atlas:getViewport(key)
  local quad = love.graphics.newQuad(x, y, w, h, canvas:getDimensions())
  -- Store (canvas, quad) in drawable wrapper
end
```

### Manifest Config Schema (Proposed)

```lua
-- In conf.lua or main.lua _config table:
config = {
  assets = {
    loading_phase = true,   -- Track ready state, emit asset:ready
    error_mode = "strict",  -- "strict" | "tolerant"
    fallbacks = {           -- Used in tolerant mode
      image = "assets/fallback.png",
      font  = "assets/fonts/default.ttf",
    },

    -- Manifest: logical key -> file path + type + optional group override
    manifest = {
      player_idle  = { path = "assets/sprites/player_idle.png",  type = "image" },
      player_run   = { path = "assets/sprites/player_run.png",   type = "image", group = "player" },
      ui_font      = { path = "assets/fonts/ui.ttf",             type = "font",  size = 16 },
      jump_sfx     = { path = "assets/sfx/jump.ogg",             type = "sound", mode = "static" },
      background   = { path = "assets/bg/title.png",             type = "image", atlas = false },  -- standalone
    },
  },
}
```

### Internal Asset Cache Structure (Recommended)

```lua
-- _assets table stores DrawableWrapper objects after loading+packing
self._assets = {}   -- key -> DrawableWrapper
self._atlases = {}  -- group_name -> { canvas, atlas_obj }
self._pending = {}  -- key -> true (while loading)
self._ready = false -- becomes true after asset:ready emitted
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| love-loader (single-thread coroutine) | Lily (multi-thread) | ~2018 | Multiple CPU cores used; faster load times |
| External atlas tools (TexturePacker) | Runtime-TextureAtlas | ~2019 | No build step; atlas built at game start |
| Binary tree packing in RTA | Cell-based packing in RTA | ~2022 | ~2x faster, better packing efficiency |
| Lily automatic event mode | Lily manual update mode | Available from early versions | Plugin architecture requires explicit control |

**Deprecated/outdated:**
- love-loader: Single-threaded coroutine approach; blocks main loop on each load step. Superseded by Lily.
- RTA fixed-size atlas: Only usable when all sprites share identical pixel dimensions. Use dynamic-size for mixed sprite projects.

---

## Open Questions

1. **Does RTA's `setMaxSize(4096, 4096)` actually error on overflow, or silently produce a larger canvas?**
   - What we know: RTA delegates to `love.graphics.newCanvas()`. The `setMaxSize` API exists and affects internal grid calculations.
   - What's unclear: Whether baking a group that exceeds 4096x4096 causes an error or silently allows a larger canvas (hardware permitting).
   - Recommendation: During implementation, test with a group that exceeds the limit on a desktop machine. If no error is thrown, the framework must pre-calculate group size and enforce the cap before calling `bake()`. Emit a clear "Group 'X' exceeded 4096x4096, splitting" warning as specified in CONTEXT.md.

2. **How does RTA expose the packed canvas for quad extraction?**
   - What we know: `getViewport(id)` returns x, y, w, h. `getDrawFuncForID(id)` returns a closure.
   - What's unclear: Whether there is a clean public accessor for the underlying `love.graphics.Canvas` or if we must use `atlas._canvas` (internal field). If internal, the auto-split implementation must be validated against RTA source.
   - Recommendation: Read RTA source code during implementation to identify the public accessor. If none exists, use `atlas._canvas` with a comment noting the internal dependency.

3. **Lily thread count and batching strategy on mobile**
   - What we know: Lily uses `love.system.getProcessorCount()` to size the thread pool. Assets are distributed across threads to minimize queue depth.
   - What's unclear: Whether batch sizes should be tuned for mobile (fewer cores) vs desktop. The CONTEXT.md leaves "Lily batch size and concurrency tuning" to Claude's discretion.
   - Recommendation: Use `lily.loadMulti()` for all manifest assets in a single batch. Lily handles thread distribution internally. No explicit batch-size tuning needed for v1.

---

## Validation Architecture

> `workflow.nyquist_validation` is not set in `.planning/config.json` — this section is included because the project has established busted testing patterns that must be accounted for in planning.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | busted (existing, see `.busted` config) |
| Config file | `.busted` (lpath includes `'./?/init.lua'`) |
| Quick run command | `busted tests/plugins/assets/` |
| Full suite command | `busted` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | File | Notes |
|--------|----------|-----------|------|-------|
| ASST-01 | Lily load does not block main thread | unit (stub Lily) | `tests/plugins/assets/asset_loader_spec.lua` | Stub Lily returns immediate callbacks; verify bus event emitted without blocking |
| ASST-02 | Sprites packed into atlas drawn from single texture | unit (stub RTA + love.graphics) | `tests/plugins/assets/atlas_builder_spec.lua` | Inject stub RTA; verify `getViewport` called; verify drawable wrapper uses canvas+quad |
| ASST-03 | Atlas config exceeding 4096x4096 rejected with clear error | unit | `tests/plugins/assets/atlas_builder_spec.lua` | Inject oversized image group; verify auto-split or error with expected message |
| ASST-04 | Lily completion callback emits bus event, not entity spawn | unit | `tests/plugins/assets/asset_loader_spec.lua` | Verify callback calls `bus:emit()` only; verify no `evolved.spawn()` calls |

### Wave 0 Gaps

- [ ] `tests/plugins/assets/init_spec.lua` — plugin lifecycle (init, update, shutdown)
- [ ] `tests/plugins/assets/asset_loader_spec.lua` — covers ASST-01, ASST-04
- [ ] `tests/plugins/assets/atlas_builder_spec.lua` — covers ASST-02, ASST-03
- [ ] `tests/plugins/assets/drawable_wrapper_spec.lua` — wrapper API
- [ ] `tests/plugins/assets/manifest_spec.lua` — manifest parsing
- [ ] `lib/lily.lua` — vendor (not yet present in lib/)
- [ ] `lib/TA.lua` (or `lib/RuntimeTextureAtlas/`) — vendor (not yet present in lib/)

---

## Sources

### Primary (HIGH confidence)
- [MikuAuahDark/lily GitHub](https://github.com/MikuAuahDark/lily) — `loadMulti`, `onComplete`, `onLoaded`, `onError`, `setUpdateMode`, `update`, `quit` API verified from README and source inspection
- [EngineerSmith/Runtime-TextureAtlas GitHub](https://github.com/EngineerSmith/Runtime-TextureAtlas) — `newDynamicSize`, `newFixedSize`, `add`, `bake`, `hardBake`, `getViewport`, `setMaxSize`, `setFilter` API verified from README
- Project codebase — `src/core/bus.lua`, `src/core/context.lua`, `src/plugins/input/init.lua`, `tests/helpers/plugin_harness.lua` read directly

### Secondary (MEDIUM confidence)
- [love2d.org/wiki/SpriteBatch](https://love2d.org/wiki/SpriteBatch) — draw call batching behavior; texture bind = batch break
- [love2d.org/wiki/love.graphics.newQuad](https://love2d.org/wiki/love.graphics.newQuad) — Quad API confirmed as built-in
- [love2d.org community forums](https://love2d.org/forums/) — graphics context requirement for tests; mobile GPU 4096 guidance

### Tertiary (LOW confidence)
- WebSearch findings on mobile GPU 4096 limits — community consensus only; verify against `love.graphics.getMaxImageSize()` at runtime

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Lily and RTA are the user-locked choices; APIs verified via GitHub
- Architecture: MEDIUM-HIGH — patterns derived from project conventions (input plugin, bus, harness) plus library docs; RTA canvas accessor detail is LOW (needs source read during implementation)
- Pitfalls: MEDIUM — window context issue is well-documented in Love2D community; `lily.quit()` is in Lily README; atlas size behavior needs empirical validation

**Research date:** 2026-03-02
**Valid until:** 2026-04-02 (stable libraries, 30-day window)
