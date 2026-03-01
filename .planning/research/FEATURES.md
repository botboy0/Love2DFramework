# Feature Landscape

**Domain:** Love2D game framework (reusable infrastructure for 2D games)
**Researched:** 2026-03-01
**Confidence:** MEDIUM — ecosystem knowledge cross-validated against project's battle-tested library choices from FactoryGame

---

## Context

This is a framework, not a game. "Features" means framework capabilities that game developers need. Existing Love2D frameworks and libraries surveyed:
- **HUMP** — class, gamestate, camera, signal, timer, vector — most-cited general utility library
- **Roomy** — scene/room management with push/pop stack
- **Windfield** — Box2D world wrapper
- **STI** — Tiled map loader, de-facto standard
- **evolved.lua** — ECS with chunk-based archetype storage (the framework's chosen ECS)
- **baton** — unified input (keyboard/gamepad/touch)
- **gamera** — camera with transform/viewport management
- **batteries** — comprehensive utility library (replaces lume, hump.vector, cpml, knife)
- **Flux** — tween/animation library
- **Lily** — threaded async asset loading
- **bitser/binser** — binary serialization
- **slick** — polygon/circle/AABB collision with slide response
- **shash** — spatial hash for broad-phase queries
- **Push** — fixed internal resolution scaling
- **Runtime-TextureAtlas** — pack sprites into atlases at startup
- **AppleCake** — Perfetto-compatible profiler

The framework's approach: curate and integrate these libraries under a unified plugin/ECS/event-bus architecture, rather than re-implement what they already do well.

---

## Table Stakes

Features developers expect. Missing = framework feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| ECS world integration | Every non-trivial Love2D game needs structured state management; raw tables fall apart at scale | High | evolved.lua; chunk-based archetype storage performs well without JIT on Android |
| Plugin/module system | Games grow in features; without isolation, everything becomes coupled spaghetti | High | `plugin:init(ctx)` pattern; each plugin is a directory with init.lua |
| Event bus (deferred) | Systems must communicate without direct coupling; deferred dispatch prevents re-entrancy bugs during ECS update | High | Queue + flush-per-tick; re-entrancy guard is non-negotiable |
| Context object pattern | All plugins need the same infrastructure (world, bus, config, services) passed consistently | Low | Single `ctx` object; avoids scattered globals |
| Unified input handling | Keyboard/gamepad/touch behave differently; games should not branch on device type | Medium | baton; action-based mapping abstracts hardware |
| Asset loading (async) | Synchronous loading causes hitches; especially bad on mobile | Medium | Lily; threaded loading with callbacks |
| Collision detection | Every game needs collision; raw AABB from scratch is a project unto itself | High | slick for collision with slide response |
| Math/utility library | Vector math, functional utilities, string/table helpers are needed constantly | Low | batteries replaces lume + hump.vector + knife + cpml |
| Tweening/animation | UI transitions, movement curves, camera lerp — everyone needs this | Low | Flux; minimal API, no dependencies |
| Serialization (save) | Games need save/load; pure-Lua serializer required for mobile/no-JIT targets | Low | binser; pure Lua, no JIT required |
| Example game | Without a working game example, developers cannot verify the framework works end-to-end | Medium | Proves integration, serves as living documentation |
| Architecture validation | Framework's value proposition is enforced clean architecture; without enforcement it degrades to suggestions | Medium | validate_architecture.lua in CI |

---

## Differentiators

Features that set this framework apart. Not expected in the Love2D ecosystem, but add meaningful value.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Enforced ECS-only game logic | HUMP, Roomy, etc. provide utilities but don't enforce where logic lives; this framework makes violation a CI failure | High | Architecture validator + CLAUDE.md; unique in Love2D ecosystem |
| Event bus as first-class infrastructure | Most frameworks bolt on signals/events; here the bus IS the inter-system communication contract | Medium | Deferred dispatch + re-entrancy guard; not just pub/sub |
| Plugin isolation by design | Plugins cannot import each other's internals; contract is enforced at architecture level, not by convention | Medium | Architecture validator catches cross-plugin require statements |
| Optional client-server via love.thread | Most Love2D frameworks ignore multiplayer entirely; this supports dual-world local transport as first-class option | High | Transport layer; architecturally supported |
| DevOps-first foundation | selene + stylua + busted + architecture validator + pre-commit hooks + CI already done before any framework code | Low | Framework ships with a working CI pipeline out of the box |
| Mobile-aware architecture | Android Love2D has no LuaJIT; library choices (evolved.lua, binser pure-Lua) are made with mobile as baseline | Medium | Galaxy A50 as performance floor; no JIT-only optimizations |
| Texture atlas pipeline | Most Love2D projects accumulate draw calls; Runtime-TextureAtlas at startup reduces this | Medium | Asset pipeline concern |
| Plugin test harness | Testing Love2D code is notoriously awkward; plugin_harness lets each plugin be tested without sibling plugins | Medium | tests/helpers/plugin_harness.lua |
| Spatial queries (broad phase) | Broad-phase spatial indexing for large worlds is not common in frameworks | Medium | shash; needed for worlds with hundreds of entities |
| Profiling integration | AppleCake + Perfetto visualization is uncommon in indie Love2D projects | Low | Helps catch performance regressions |

---

## Anti-Features

Features to deliberately NOT build.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Game-specific logic (inventory, crafting, combat) | Domain-specific; makes framework non-genre-agnostic | Implement as plugins using the framework |
| Scene/state management (v1) | Roomy-style push/pop stacks force opinions about game structure | Games add Roomy as a plugin if needed; defer to v2 |
| Custom UI system | UI is opinionated; every game has different needs | Games use Slab/cimgui-love for debug; game UI is game code |
| Hot-reload | Defeats static analysis guarantees; creates inconsistent ECS state | Fast Love2D restart |
| Custom ECS implementation | evolved.lua is battle-tested; a custom ECS is months of work | Integrate evolved.lua; contribute upstream |
| Internet multiplayer (v1) | Requires NAT traversal, lag compensation, authority models | Defer; transport layer is architecturally supported |
| Integrated physics engine | Most 2D games need collision response, not constraint-solver physics | slick for collision; games needing physics add Windfield |
| Asset hot-swap at runtime | Breaks reproducibility, conflicts with texture atlas pre-packing | Restart-based workflow |

---

## Feature Dependencies

```
Plugin registry + ctx object
    --> ECS world integration (world passed via ctx)
    --> Event bus (bus passed via ctx)
    --> All plugins (plugins receive ctx on init)

Event bus (deferred dispatch + re-entrancy guard)
    --> All inter-system communication
    --> Plugin test harness (bus is mocked in harness)

ECS world integration
    --> Collision detection (slick entities registered in world)
    --> Spatial queries (shash indexed from world positions)
    --> Asset loading (asset handle components on entities)

Asset loading (Lily async)
    --> Texture atlas pipeline (atlases built after async load completes)

Plugin test harness
    --> Plugin registry + ctx object (harness provides minimal ctx)
    --> Event bus (harness provides mock bus)

Example game
    --> ALL framework features (proves integration)
```

---

## MVP Recommendation

Prioritize for v1:

1. **Plugin registry + context object** — Everything else is built on top
2. **Deferred event bus with re-entrancy guard** — The communication contract
3. **ECS world management** — evolved.lua integration
4. **Plugin test harness** — Must exist early
5. **Canonical plugin example** — Living documentation
6. **Unified input handling** — baton integration as a plugin
7. **Asset pipeline** — Lily async loading + texture atlas
8. **Example game** — Proves it all works together

---

## Implementation Risk Notes

The re-entrancy guard on the event bus is the single highest-risk feature. A naive pub/sub causes non-deterministic bugs when a handler emits another event during ECS world iteration. This warrants dedicated unit tests before any other feature touches the bus.

The dual-world client-server option is the highest-complexity feature. The synchronization contract between simulation and presentation worlds is novel in the Love2D ecosystem. Should be a separate phase from core infrastructure.

---

## Sources

- `.planning/PROJECT.md` — HIGH confidence (project design decisions)
- `CLAUDE.md` — HIGH confidence (architectural rules, enforcement model)
- Love2D ecosystem library analysis — MEDIUM confidence
- Love2D community conventions — MEDIUM confidence

---
*Feature research for: Love2D Game Framework*
*Researched: 2026-03-01*
