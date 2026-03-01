# Technology Stack

**Project:** Love2DFramework
**Researched:** 2026-03-01
**Confidence:** MEDIUM (vendored libraries verified from source; unvendored libraries from PROJECT.md curation + ecosystem knowledge)

---

## Current State (Vendored in lib/)

Two libraries are already vendored and confirmed:

| Library | Confirmed Version | Source |
|---------|------------------|--------|
| evolved.lua | 1.10.0 | `lib/evolved.lua` header |
| binser | 0.0-8 | `lib/binser.lua` header |

---

## Recommended Stack

### Runtime Foundation

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Love2D | 11.5 | Game framework | Confirmed in `conf.lua`. Stable release. Stay on 11.5 — 12.x breaks backwards compat. |
| Lua | 5.1 | Language runtime | Love2D bundles LuaJIT (5.1 compat) on desktop; Android uses vanilla Lua 5.1 (no JIT). Framework MUST target 5.1 floor. |

### ECS

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| evolved.lua | 1.10.0 (vendored) | Entity-Component-System | Already vendored; every core module depends on it. Chunk-based archetype storage. Tag-fragment pattern enables dual-world isolation. Do NOT replace. |

### Serialization

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| binser | 0.0-8 (vendored) | love.thread transport + save serialization | Already vendored. Pure Lua, no JIT required. |
| bitser | latest (deferred) | Network message serialization | Faster binary encoding for hot-path network messages. Add when remote networking begins. |

### Networking / Transport

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| love.thread channels | built-in | Local client-server transport | Zero-dependency IPC via Love2D built-in. |
| Raw ENet | built-in | Remote networking (deferred) | Love2D bundles ENet. Deferred until local transport is solid. |

### Input

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| baton | latest | Keyboard / gamepad / touch unification | Required for mobile target. Maps actions to input devices. Vendor as `lib/baton.lua`. |

### Tilemap

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| STI | latest | Tiled .tmx map loading | Industry standard for Love2D Tiled integration. Vendor as `lib/sti/`. |

### Physics / Spatial

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| slick | latest | Collision with slide response | Pure Lua, no love.physics dependency. Works on Android. |
| shash | latest | Broad-phase spatial hashing | O(1) proximity queries. Spatial index service for narrow-phase collision. |

### Math / Utilities

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| batteries | latest | General-purpose utility library | Replaces lume + hump + knife + cpml as a single vendored unit. |

### Camera / Resolution

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| gamera | latest | Camera with bounds and transform | Minimal, well-understood. Optional — games use it, not framework core. |
| Push | latest | Fixed internal resolution scaling | Required for pixel-perfect rendering on mobile (variable DPI). |

### Asset Pipeline

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Runtime-TextureAtlas | latest | Pack sprites into atlases at startup | Eliminates texture switches, critical for mobile GPU. |
| Lily | latest | Threaded async asset loading | Prevents frame hitches during level transitions. |

### Animation / Tweening

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Flux | latest | Tweening for animations and UI | Minimal, chainable. |

### Profiling

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| AppleCake | latest | Perfetto profiling | Flamegraph output in Chrome. Development builds only. |

### Debug UI

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Slab | latest | ImGui-style devtools UI | Pure Lua. Dev tools only, not game UI. Preferred over cimgui-love (requires compiled .so). |

### DevOps (Confirmed — Already Working)

| Tool | Version | Purpose |
|------|---------|---------|
| selene | 0.27.1 | Lua linting with `unscoped_variables = "deny"` |
| stylua | 0.20.0 | Lua formatting (tabs, 120-col) |
| busted | latest | Unit/integration testing |
| validate_architecture.lua | project-owned | Architectural enforcement |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| ECS | evolved.lua | concord, nata | Already vendored; replacing means full rewrite |
| Transport serialization | binser | lua-MessagePack | binser already vendored |
| Input | baton | Raw love.keyboard | No gamepad/touch remapping |
| Utilities | batteries | lume + hump + knife | More vendor surface, less consistent API |
| Debug UI | Slab | cimgui-love | cimgui-love needs compiled C .so — not viable for Android/CI |
| Collision | slick | love.physics | love.physics has Android issues; slick is pure Lua |
| Camera | gamera | HUMP camera | gamera is minimal; HUMP effectively unmaintained |

---

## Version Constraints

### No JIT Extensions in Framework Code

Love2D on Android = vanilla Lua 5.1 with no JIT. `src/` code must not use:
- `require "jit"` or `jit.*`
- LuaJIT FFI (`require "ffi"`)
- LuaJIT bit operations (use `bit32` or pure Lua substitutes)

### Love2D 11.5 Target

Stay on 11.5 until v1 ships. Love2D 12.x breaks backwards compatibility.

---

## Vendoring Plan

13 libraries remain to vendor:

| Priority | Library | When |
|----------|---------|------|
| 1 | batteries | Core infrastructure (utility dependency) |
| 2 | baton | Input plugin phase |
| 3 | slick | Collision integration phase |
| 4 | shash | Collision integration phase |
| 5 | Lily | Asset pipeline phase |
| 6 | Runtime-TextureAtlas | Asset pipeline phase |
| 7 | STI | Tilemap support (example game or v2) |
| 8 | gamera | Camera integration (optional) |
| 9 | Push | Resolution scaling (optional) |
| 10 | Flux | Animation/tweening (optional) |
| 11 | Slab | Developer tools phase |
| 12 | AppleCake | Developer tools phase |
| 13 | bitser | Remote networking (deferred) |

---

## Sources

| Source | Confidence |
|--------|------------|
| `lib/evolved.lua` header | HIGH |
| `lib/binser.lua` header | HIGH |
| `conf.lua` — Love2D 11.5 | HIGH |
| `.github/workflows/ci.yml` — selene 0.27.1, stylua 0.20.0 | HIGH |
| `PROJECT.md` library table | MEDIUM |
| Unvendored library ecosystem knowledge | LOW-MEDIUM |

---
*Stack research for: Love2D Game Framework*
*Researched: 2026-03-01*
