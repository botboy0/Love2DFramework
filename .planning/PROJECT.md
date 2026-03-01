# FactoryGame

## What This Is

A top-down pixel art factory game built in Love2D, blending Satisfactory's factory automation with Terraria's exploration, crafting, and combat. Procedurally generated infinite world, 16x16 tile-based, with a client-server architecture that runs identically in solo and multiplayer. Players mine resources by hand, discover recipes through a notebook system, build processing chains, and progress through technology ages — from stone tools on a beach to magitech megafactories.

## Core Value

The discovery-driven progression loop: every new material found reveals tantalizing recipe hints in the notebook, pulling the player deeper into exploration and more complex automation chains.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Client-server architecture (local server via love.thread for solo, ENet for multiplayer)
- [ ] Full ECS game logic using evolved.lua — all state lives in the ECS
- [ ] Event-driven communication between systems (signal bus, no direct calls)
- [ ] Plugin-based feature modules with standard registration API
- [ ] Chunk-based infinite procedural world generation (server-side)
- [ ] 16x16 tile rendering with SpriteBatch optimization
- [ ] Player entity: 8-dir movement, inventory/hotbar, melee + ranged combat, place/break tiles
- [ ] Manual resource gathering (pick up items, chop trees, mine rocks)
- [ ] Automated resource extraction (drills/extractors in later ages)
- [ ] Conveyor belts (solids) and pipes (fluids) for logistics
- [ ] Ground crafting system (place items near each other to combine)
- [ ] Notebook/discovery system (recipes revealed as materials are found)
- [ ] Survival mechanics (hunger, thirst, health)
- [ ] Combat with hostile creatures and bosses
- [ ] Dual progression: tech tree research + boss gates unlock new tiers/ages
- [ ] Age 0 MVP: beach survival to first copper tool
- [ ] DevOps enforcement stack: linting, testing, CI, architectural validation
- [ ] ECS-first persistence (serialize/deserialize ECS state directly)

### Out of Scope

- 3D rendering — start 2D, upgrade later (ECS makes this a clean swap)
- Day/night cycle — add later if it adds value
- Age 1+ content — v1 is Age 0 only
- Fancy notebook UI — track recipes server-side, defer UI to post-MVP
- Death penalty — no item loss on death for MVP

## Context

### Previous Development
An earlier version of this game was built with Love2D. Key lessons learned:
- ECS with evolved.lua works well and should be carried forward
- Pixel-analyzed tile collision (slick library) was effective
- Client-server via love.thread is viable for solo play on mobile
- Code quality degraded without enforcement — inconsistent style, architecture drift, tight coupling, scattered state. This time, **devops and architectural enforcement come first, before any game code.**

### Architecture Decisions (Carried Forward)
- **Client-server always**: even solo runs a local server via love.thread
- **Server-authoritative**: all game state owned by server, client is thin renderer
- **Client prediction**: player movement predicted locally, corrected by server
- **ECS-first**: evolved.lua for both server simulation and client rendering
- **Event-driven**: systems communicate through a signal/event bus, never directly
- **Plugin architecture**: each feature is a self-contained module registering components, systems, and event handlers through a standard API
- **Chunk-based world**: load/unload chunks as player moves, server streams to client
- **ECS-first persistence**: the ECS state IS the save data

### Target Platforms
- Desktop (Windows/Linux/Mac) and Android equally
- Samsung Galaxy A50 as mobile baseline (Mali-G72 MP3, Exynos 9610, 4GB RAM)
- LuaJIT disabled on Android Love2D — minimize client-side Lua computation
- Draw call budget: <100, aim for <50

### Library Stack (Starting Point — May Evolve)
| Category | Library | Notes |
|---|---|---|
| ECS | evolved.lua | Chunk-based entity storage |
| Networking | Raw ENet (built-in) | + love.thread channels for local server |
| Serialization (net) | bitser | Fast binary |
| Serialization (save) | binser | Pure Lua, no JIT needed |
| Tilemap | STI | Standard Tiled loader |
| Input | baton | KB/gamepad/touch unification |
| Camera | gamera | Or custom minimal |
| Collision | slick | Polygon/circle/AABB with slide response |
| Spatial queries | shash | Broad-phase proximity |
| Math/Utilities | batteries | Replaces lume, hump, knife, cpml |
| Texture Atlas | Runtime-TextureAtlas | Pack sprites at startup |
| Resolution | Push | Fixed internal res scaling |
| Tweening | Flux | Animations, UI transitions |
| Profiling | AppleCake | Perfetto visualization |
| Async Loading | Lily | Threaded asset loading |
| UI (debug) | Slab or cimgui-love | Dev tools |
| UI (game) | Custom | Inventory, HUD |

### DevOps & Architectural Enforcement (FIRST PRIORITY)
The devops stack must be in place before any game code is written:

**Linting & Formatting:**
- selene or luacheck with custom rules to catch ECS/event violations
- stylua for consistent formatting
- Pre-commit hooks that hard-block non-conforming code

**Testing:**
- Unit/integration test framework (busted or similar)
- Each plugin must be testable in isolation
- Tests verify modularity: features work without other features loaded

**CI Pipeline:**
- GitHub Actions: lint, test, build on every push
- Hard block on merge if any check fails

**Architectural Rules (Enforced):**
- All game logic MUST go through the ECS (no logic outside systems)
- All inter-system communication MUST go through the event bus (no direct calls)
- Each feature is a plugin with a standard init() API — registers components, systems, event handlers
- No feature may access another feature's internals
- Single source of truth: game state lives in the ECS, nowhere else
- No global mutable state outside the ECS world

## Constraints

- **Tech stack**: Love2D (Lua) client, Lua server (love.thread for local, potential Java/LuaJIT for remote later)
- **Performance**: Galaxy A50 at 60fps — aggressive batching, spatial culling, thin client
- **No JIT on Android**: interpreted Lua only on mobile — server offloads simulation
- **Architecture**: ECS-first, event-driven, plugin-based — enforced, not optional
- **Art**: 16x16 pixel art tiles, sourced from itch.io packs initially

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| DevOps before game code | Previous attempt degraded without enforcement | — Pending |
| Client-server always (even solo) | Same architecture for solo and multiplayer, no rewrite needed | — Pending |
| Start 2D, upgrade to 3D later | More tilesets available, faster iteration, ECS makes render swap clean | — Pending |
| Plugin-based features | Prevents coupling, enforces modularity, each feature testable in isolation | — Pending |
| ECS-first persistence | ECS state IS the save data — no separate save format to maintain | — Pending |
| Age 0 as MVP | Focused scope: beach to copper tool, no machines/automation yet | — Pending |
| Hard-block enforcement | CI and pre-commit hooks reject non-conforming code, no exceptions | — Pending |

---
*Last updated: 2026-03-01 after initialization*
