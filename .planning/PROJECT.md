# Love2D Framework

## What This Is

An open-source, genre-agnostic Love2D game framework for building bigger and more complex 2D games. Extracted from a real game project (FactoryGame), it provides ECS-first architecture with evolved.lua, event-driven plugin systems, optional client-server networking, asset management, and unified input handling — all enforced by a devops stack that prevents architectural drift.

## Core Value

A framework that enforces clean architecture by default — ECS-only game logic, event-bus-only communication, isolated plugins — so games stay maintainable as they grow in complexity.

## Requirements

### Validated

- ✓ selene linting with `unscoped_variables = "deny"` and Love2D std definition — existing
- ✓ stylua formatting enforced on all Lua source files — existing
- ✓ Pre-commit hooks running selene + stylua; hard-block non-conforming commits — existing
- ✓ GitHub Actions CI pipeline: lint → format → test → validate; hard-block on failure — existing
- ✓ busted test framework with plugin test harness — existing
- ✓ CLAUDE.md with architectural enforcement rules — existing
- ✓ Architecture validator script in CI — existing

### Active

- [ ] Deferred-dispatch event bus with queue + flush-per-tick and re-entrancy guard
- [ ] Plugin registry with standard `plugin:init(ctx)` API; `ctx = { world, bus, config, services }`
- [ ] ECS world management (single-world for simple games, dual-world for client-server)
- [ ] Optional love.thread channel transport for client-server communication
- [ ] Context object pattern — single `ctx` passed to all plugins
- [ ] Plugin isolation test template — each plugin loadable and testable without sibling plugins
- [ ] Canonical plugin example as reference implementation
- [ ] Asset pipeline — texture atlases (Runtime-TextureAtlas), async loading (Lily), resource management
- [ ] Unified input system — keyboard/gamepad/touch via baton
- [ ] At least one example game demonstrating the framework
- [ ] Documentation sufficient for someone to clone, read, and build a game

### Out of Scope

- Game-specific logic (inventory, crafting, combat) — that's game code, not framework
- Scene/state management — defer to v2 (useful but not core infrastructure)
- Camera + resolution scaling — defer to v2 (games can integrate gamera/Push directly)
- 3D rendering — 2D framework only
- Multiplayer networking over the internet (ENet remote) — transport layer supports it architecturally, but remote implementation deferred
- Custom game UI system — games build their own
- Hot-reload — defeats static analysis, use fast restart

## Context

### Origin
Extracted from FactoryGame, a top-down pixel art factory game. FactoryGame's Phase 1 (DevOps) was completed and carried forward. Phase 2 (Core Infrastructure) was planned but not started — that work becomes this framework's first milestone, generalized beyond FactoryGame's specific needs.

### Lessons Learned (from FactoryGame)
- ECS with evolved.lua works well for complex game state
- Code quality degrades fast without enforcement — devops must come first (done)
- Client-server via love.thread is viable for solo play
- Plugin architecture prevents the tight coupling that killed the previous attempt
- selene rule is `unscoped_variables = "deny"` (not `global_usage`)
- Test files need separate selene.toml with `love2d_busted` std

### Target Audience
Open-source Love2D framework. Users are game developers (solo or small teams) who want structured architecture for non-trivial Love2D games without reinventing infrastructure.

### Library Stack
| Category | Library | Notes |
|---|---|---|
| ECS | evolved.lua | Core — chunk-based entity storage |
| Networking | Raw ENet (built-in) | + love.thread channels for local transport |
| Serialization (net) | bitser | Fast binary for network messages |
| Serialization (save) | binser | Pure Lua, no JIT needed |
| Tilemap | STI | Standard Tiled loader |
| Input | baton | KB/gamepad/touch unification |
| Camera | gamera | Optional integration |
| Collision | slick | Polygon/circle/AABB with slide response |
| Spatial queries | shash | Broad-phase proximity |
| Math/Utilities | batteries | Replaces lume, hump, knife, cpml |
| Texture Atlas | Runtime-TextureAtlas | Pack sprites at startup |
| Resolution | Push | Fixed internal res scaling |
| Tweening | Flux | Animations, UI transitions |
| Profiling | AppleCake | Perfetto visualization |
| Async Loading | Lily | Threaded asset loading |
| UI (debug) | Slab or cimgui-love | Dev tools only |

## Constraints

- **Tech stack**: Love2D (Lua) — framework must work with standard Love2D distribution
- **Performance**: Must support mobile targets (Galaxy A50 baseline) — no JIT on Android Love2D
- **Architecture**: ECS-first, event-driven, plugin-based — enforced by tooling, not optional
- **Genre-agnostic**: Framework must not assume any specific game type
- **Backwards compatibility**: Breaking changes require major version bump once v1 ships

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| DevOps before framework code | Carried from FactoryGame — enforcement prevents drift | ✓ Good |
| Optional client-server | Simple games need one world; complex games need dual worlds + transport | — Pending |
| Same library stack as FactoryGame | Battle-tested choices, no need to re-evaluate | — Pending |
| Genre-agnostic design | Framework serves any 2D game, not just top-down factory games | — Pending |
| Example game required for v1 | Proves the framework works end-to-end, serves as documentation | — Pending |
| Asset pipeline in v1 | Texture atlases + async loading are infrastructure, not game-specific | — Pending |

---
*Last updated: 2026-03-01 after initialization*
