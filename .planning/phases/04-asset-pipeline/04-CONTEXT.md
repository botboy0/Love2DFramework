# Phase 4: Asset Pipeline - Context

**Gathered:** 2026-03-02
**Status:** Ready for planning

<domain>
## Phase Boundary

Assets load without frame hitches and draw calls are minimized by atlas packing — targeting mobile GPU compatibility. Covers async loading via Lily, texture atlas packing via Runtime-TextureAtlas, and the asset service API. Does not include rendering systems, scene management, or asset hot-swap.

</domain>

<decisions>
## Implementation Decisions

### Loading Lifecycle
- Load-then-pack pipeline: Lily loads all images async first, then Runtime-TextureAtlas packs them into atlases once all images are in memory. Two distinct phases.
- Both manifest-driven (startup batch) and on-demand (mid-game) loading supported
- Manifest defined in `ctx.config.assets` following the existing config-driven pattern (like `ctx.config.input`)
- Lily completion callbacks queue bus events (deferred dispatch naturally prevents mid-tick entity spawning)
- Three event granularities: `asset:loaded { key, type, path }` per-asset, `asset:batch_complete { keys }` per-batch, `asset:ready` when all manifest assets loaded and atlases packed
- Configurable loading phase via `ctx.config.assets.loading_phase` (default `true`) — when enabled, plugin tracks ready state, exposes `assets:is_ready()`, and emits `asset:ready`

### Asset API Surface
- Service registered as `"assets"` via `ctx.services:register`
- Both service (direct access for fonts, sounds, non-entity assets) and ECS components (for entity-bound sprites resolved by render systems)
- Assets referenced by manifest logical keys, not file paths — decouples game code from file structure
- Manifest assets: `assets:get(key)` errors if asset not loaded (fail-fast — if loading phase completed, asset must exist)
- On-demand assets: `assets:get(key)` returns nil while loading in progress
- Atlas quads transparent by default — `assets:get("player_idle")` returns a drawable wrapper regardless of atlas vs standalone
- Explicit atlas access available for power users: `assets:get_atlas("characters")` for raw quad/texture access

### Atlas Packing Strategy
- Directory-based group assignment by default (sprites in `assets/characters/` become the "characters" atlas)
- Manifest overrides to reassign specific sprites to custom groups
- One atlas per group for natural draw call batching
- Auto-split safety net: if a group exceeds 4096x4096, automatically split into multiple atlases
- Non-atlas sprites (backgrounds, large textures) load as standalone `love.graphics.Image` via Lily
- Atlases built once during loading phase and frozen — no runtime repacking (v1)

### Error Handling
- Configurable `error_mode` (strict/tolerant) following existing framework pattern on bus and registry
- Strict mode (default): error and halt on any failed asset load
- Tolerant mode: log warning, skip failed asset — `assets:get(key)` returns nil for failed assets
- Optional fallback assets per type via `ctx.config.assets.fallbacks = { image = "path", font = "path", sound = "path" }` — used in tolerant mode instead of nil. If fallback itself fails to load, crash (broken configuration)
- Warning emitted on atlas auto-split: "Group 'X' split into N atlases (exceeded 4096x4096). Consider splitting into smaller groups."

### Asset Types (v1)
- Images (`love.graphics.newImage`) — primary, atlas-eligible
- Fonts (`love.graphics.newFont`) — standalone, async via Lily
- Sounds (`love.audio.newSource`) — standalone, async via Lily

### Claude's Discretion
- Internal cache/storage structure for loaded assets
- Lily batch size and concurrency tuning
- Drawable wrapper implementation details
- Exact manifest config table schema (beyond the decisions captured here)
- Atlas packing algorithm parameters (padding, sorting)

</decisions>

<specifics>
## Specific Ideas

- Loading lifecycle explained as two distinct phases: I/O phase (Lily async) then optimization phase (atlas packing) — user understood and explicitly chose this separation
- Fallback assets are a safety net for production: prevent invisible sprites without crashing, but a broken fallback is a hard crash (config error, not recoverable)
- Framework provides no built-in loading screen — bus events are sufficient for game code to build its own

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/core/bus.lua`: Deferred-dispatch event bus with `emit()` / `on()` / `flush()` — Lily callbacks queue events here
- `src/core/context.lua`: Context factory with `Services` registry — asset plugin registers via `ctx.services:register("assets", ...)`
- `src/core/registry.lua`: Plugin registry with topological sort, `error_mode` support — asset plugin follows same pattern

### Established Patterns
- Config-driven plugin initialization: `ctx.config.input` pattern → `ctx.config.assets` for manifest and settings
- `error_mode = "strict" | "tolerant"` with per-module overrides via `ctx.config.error_modes.assets`
- Service registration: stateless query providers via `ctx.services:register(name, provider)`
- Plugin structure: directory with `init.lua`, `name` and `deps` fields, `init(ctx)` / `update(dt)` / `shutdown(ctx)` lifecycle

### Integration Points
- `src/core/plugin_list.lua`: Asset plugin must be added here with its dependencies
- `main.lua`: `love.update` calls `registry:update_all(dt)` then `bus:flush()` — Lily polling happens in plugin's `update()`
- `src/core/components.lua`: Sprite/Asset ECS components registered here (centralized, no `evolved.id()` in plugins)

</code_context>

<deferred>
## Deferred Ideas

- Runtime atlas repacking (dynamic atlas updates mid-game) — potential v2 feature
- Asset hot-swap / hot-reload — explicitly out of scope per REQUIREMENTS.md
- Data file loading (JSON, Lua tables) — beyond v1 asset types
- Compressed asset support — niche, future if needed

</deferred>

---

*Phase: 04-asset-pipeline*
*Context gathered: 2026-03-02*
