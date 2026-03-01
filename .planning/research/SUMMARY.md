# Project Research Summary

**Project:** Love2DFramework
**Domain:** Reusable Love2D game framework (ECS + event bus + plugin registry)
**Researched:** 2026-03-01
**Confidence:** HIGH

## Executive Summary

Love2DFramework is a reusable infrastructure layer for 2D games built on Love2D and Lua. It is not a game — it is a framework that game developers drop into projects to get a structured, testable, ECS-first foundation. The recommended approach is already well-defined by the project's own architecture: an evolved.lua ECS world as the single source of truth, a deferred event bus as the only inter-plugin communication channel, and a plugin registry with dependency-sorted boot. Everything in the framework should reinforce this contract rather than provide escape hatches from it. The value proposition is not a collection of utilities (those already exist as standalone Lua libraries) but enforced clean architecture where violations are CI failures, not convention.

The build order is dictated by strict layered dependencies. Vendored libraries (evolved.lua, binser) are already in place. Core infrastructure — components, bus, worlds, context, registry — must be built as a unit before any plugin can exist. Only after the core layer is complete and tested can feature plugins (input, assets, collision) be layered on top, followed by an example game that proves end-to-end integration. Skipping or reordering these layers will cause implicit dependency bugs that are hard to diagnose.

The two highest risks are architectural discipline erosion and the global evolved.lua singleton. Every phase risks encoding FactoryGame-specific concepts into generic infrastructure, slowly making the framework non-reusable. The evolved.lua global singleton requires all entity creation to go through scoped helpers — raw `evolved.spawn()` anywhere in plugin code will silently break world isolation. Both risks require active prevention: the architecture validator for the singleton, and end-of-phase "would a puzzle game need to remove this?" reviews for genre creep.

---

## Key Findings

### Recommended Stack

Two libraries are already vendored and form the non-negotiable foundation: evolved.lua 1.10.0 (ECS, chunk-based archetype storage) and binser 0.0-8 (pure-Lua serialization). The project targets Love2D 11.5 and Lua 5.1 as the floor — Love2D on Android uses vanilla Lua 5.1 with no JIT, which rules out any FFI, `jit.*`, or LuaJIT bit operations in framework code. Staying on 11.5 until v1 ships is mandatory; Love2D 12.x breaks backwards compatibility.

The unvendored libraries are ready for adoption but must be vendored at the right phase. batteries is the highest-priority unvendored library — it replaces lume, hump.vector, knife, and cpml as a unified dependency and should be vendored during core infrastructure. Input (baton), collision (slick + shash), and asset pipeline (Lily + Runtime-TextureAtlas) follow during their respective plugin phases. Developer tooling (Slab, AppleCake) and networking (bitser, raw ENet) are explicitly deferred.

**Core technologies:**
- evolved.lua 1.10.0: ECS world — already vendored; chunk-based archetype storage performs well without JIT
- binser 0.0-8: serialization — already vendored; pure Lua, no JIT required
- Love2D 11.5: game framework — confirmed in `conf.lua`; stay on 11.5 until v1 ships
- batteries: utility library — vendor during core infrastructure; replaces four separate libraries
- baton: unified input — vendor during input plugin phase; required for mobile target
- slick + shash: collision + spatial queries — vendor together during collision phase
- Lily + Runtime-TextureAtlas: async asset loading + atlas packing — vendor during asset pipeline phase

See `.planning/research/STACK.md` for full vendoring priority list and alternatives considered.

### Expected Features

This is a framework, so "features" means framework capabilities. The framework's must-haves are the contracts that plugins depend on. Every feature plugin is blocked until the core contract (plugin registry, event bus, ECS context) is stable.

**Must have (table stakes):**
- Plugin registry + context object — everything depends on `plugin:init(ctx)`
- Deferred event bus with re-entrancy guard — the inter-system communication contract; re-entrancy is non-negotiable
- ECS world management — evolved.lua integration with tag-based world isolation
- Plugin test harness — must exist early; tests/helpers/plugin_harness.lua
- Canonical plugin example — living documentation in examples/canonical_plugin.lua
- Unified input handling — baton integration; required for gamepad/touch targets
- Async asset loading — Lily + texture atlas; synchronous loading hitches on mobile
- Architecture validator in CI — the framework's value proposition requires enforcement
- Example game — proves end-to-end integration; required before claiming v1

**Should have (differentiators):**
- Enforced plugin isolation — cross-plugin requires are CI failures, not convention
- Collision detection with slide response — slick + shash broad-phase spatial indexing
- Profiling integration — AppleCake + Perfetto; uncommon in indie Love2D projects
- Optional client-server transport — love.thread channel bridge with binser; architecturally supported but not required

**Defer to v2+:**
- Scene/state management (Roomy-style push/pop stacks)
- Internet multiplayer (raw ENet; requires NAT traversal, authority models)
- Custom UI system
- Hot-reload
- bitser for network message serialization (add when ENet phase begins)

**Anti-features (do not build):**
- Game-specific logic in core (inventory, crafting, combat belong in game plugins)
- Components in core beyond geometric primitives and lifecycle tags
- Asset hot-swap at runtime

See `.planning/research/FEATURES.md` for full feature dependency graph and MVP recommendation.

### Architecture Approach

The architecture has six layers with strict upward-only dependency flow. Layer 0 (vendored libraries) is complete. Layers 1-4 (components, bus/worlds, context/transport, registry) constitute core infrastructure and must be built as a unit. Layers 5-6 (feature plugins, example game) build on top. The key patterns are: deferred event bus (queue during update, flush at end of tick), tag-based world isolation (evolved.lua singleton scoped by ServerTag/ClientTag fragments), and plugin context injection (all plugins receive the same `ctx = { worlds, bus, config, services }`). Client-server separation (Layer 3 transport) is optional — single-world games skip world tags and the transport module entirely.

**Major components:**
1. `src/core/components.lua` — single source of truth for all evolved.lua fragment IDs; no plugin defines IDs outside this file
2. `src/core/bus.lua` — deferred-dispatch event bus; queue + flush-per-tick; re-entrancy guard blocks emissions during flush
3. `src/core/worlds.lua` — tag-based dual world isolation; all entity creation through scoped helpers
4. `src/core/context.lua` — DI container passed to all plugins via `plugin:init(ctx)`
5. `src/core/registry.lua` — topological boot + reverse shutdown; `plugin_list.lua` is the explicit manifest
6. `src/core/transport.lua` — love.thread channel bridge with binser serialization (optional)

### Critical Pitfalls

1. **evolved.lua global singleton** — raw `evolved.spawn()` anywhere in plugin code bypasses world isolation. All entity creation must go through `worlds` helpers. Architecture validator must flag raw spawn calls in plugin files. Address this during core infrastructure before any plugin is written.

2. **Event bus re-entrancy silently discards events** — `bus:emit()` inside a `bus:on()` handler is silently dropped with a log warning. Handlers may not emit. All emissions happen in systems during `update()` before `bus:flush()`. Document in canonical plugin example; add a test that confirms the warning is logged.

3. **Component IDs defined per-plugin instead of centrally** — `evolved.id()` calls anywhere outside `src/core/components.lua` create ID conflicts. Architecture validator must flag `evolved.id(` in plugin files. Add this check before the first plugin is written.

4. **Plugin order-dependent behavior without declared dependencies** — `ctx.services:get("X")` without a declared `deps` entry works by coincidence until plugin order changes. Plugin harness must fail on undeclared service access; architecture validator cross-references service calls against declared deps.

5. **Genre-specific concepts leaking into core infrastructure** — `src/core/components.lua` shipping with Inventory or Crafting, transport hardcoding gameplay events, documentation using FactoryGame terminology. Prevention: core ships with only Position, Velocity, Size, and world tags. Apply "would a puzzle game need to remove this?" review at the end of every core infrastructure phase.

See `.planning/research/PITFALLS.md` for moderate pitfalls (love.thread blocking, fragment ID thread divergence, stateful services) and phase-specific warning table.

---

## Implications for Roadmap

Based on research, the dependency layers directly map to roadmap phases. There is no flexibility in Phase 1 ordering — everything in core infrastructure depends on everything else in core infrastructure. Feature plugins cannot be started until the core contract is stable and tested.

### Phase 1: Core Infrastructure

**Rationale:** Layers 1-4 from ARCHITECTURE.md must be built together. The event bus, ECS worlds, context object, and plugin registry have circular design dependencies — you cannot meaningfully test any one of them without the others. This is the highest-risk phase because architectural decisions made here propagate to every plugin.

**Delivers:** A working, tested framework skeleton with no game logic. A developer can register a plugin and have it receive `ctx` with a working bus and ECS world.

**Addresses:** Plugin registry + context object, deferred event bus, ECS world management, plugin test harness (FEATURES.md table stakes 1-4)

**Avoids:** Pitfalls 1 (singleton), 2 (re-entrancy), 3 (per-plugin IDs), 4 (implicit deps), 5 (genre creep), 8 (stateful services), 10 (shutdown not wired)

**Libraries to vendor:** batteries (utility dependency used throughout)

**Validator checks to add:** `evolved.spawn(` in plugin files, `evolved.id(` in plugin files, `ctx.services:get()` without declared deps

### Phase 2: Canonical Plugin Example and Test Infrastructure

**Rationale:** Before any feature plugin is written, the canonical pattern must be codified in `examples/canonical_plugin.lua` and the plugin test harness must exist in `tests/helpers/plugin_harness.lua`. Every subsequent plugin is developed against this pattern. Writing feature plugins before the harness exists means retrofitting tests later.

**Delivers:** `examples/canonical_plugin.lua` as living documentation, `tests/helpers/plugin_harness.lua` for plugin isolation testing, and validation that the core layer is actually usable as an API.

**Addresses:** Canonical plugin example, plugin test harness (FEATURES.md table stakes 4-5)

**Avoids:** Pitfall 4 (harness fails on undeclared deps), Pitfall 5 (generic placeholder names in example)

### Phase 3: Input Plugin

**Rationale:** Input is the simplest feature plugin and a good first exercise of the plugin pattern. baton is a well-understood library with minimal integration surface. This phase proves the plugin system works for a real use case.

**Delivers:** `src/plugins/input/` plugin wrapping baton with action-based mapping; keyboard, gamepad, and touch unified.

**Addresses:** Unified input handling (FEATURES.md table stakes)

**Libraries to vendor:** baton

**Avoids:** Pitfall 5 (input plugin must not encode game-specific actions in core)

### Phase 4: Asset Pipeline Plugin

**Rationale:** All subsequent plugins (collision, rendering, example game) need assets. Lily async loading and texture atlas packing must be in place before the example game phase.

**Delivers:** `src/plugins/assets/` plugin wrapping Lily for async loading; Runtime-TextureAtlas for atlas packing at startup; asset handle components on ECS entities.

**Addresses:** Async asset loading, texture atlas pipeline (FEATURES.md table stakes)

**Libraries to vendor:** Lily, Runtime-TextureAtlas

**Avoids:** Pitfall 11 (mobile 4096x4096 atlas cap), Pitfall 12 (Lily callbacks emit bus events only — no direct entity spawn)

### Phase 5: Collision Plugin

**Rationale:** Collision is needed for any non-trivial example game. slick and shash integrate as a pair — broad-phase (shash) feeds narrow-phase (slick). Both vendor together.

**Delivers:** `src/plugins/collision/` plugin with slick collision detection and shash spatial indexing; spatial query service available to other plugins via `ctx.services`.

**Addresses:** Collision detection, spatial queries (FEATURES.md table stakes)

**Libraries to vendor:** slick, shash

**Avoids:** Pitfall 4 (spatial service must be declared as dep), Pitfall 8 (spatial index service must expose query accessors only — no mutable cached state)

### Phase 6: Optional Transport Layer

**Rationale:** The love.thread client-server transport is architecturally supported but optional. Single-world games skip this entirely. This phase should be explicitly scoped as optional infrastructure for games that need local client-server separation or will later add ENet networking.

**Delivers:** `src/core/transport.lua` channel bridge with binser serialization; ServerTag/ClientTag world isolation patterns documented.

**Addresses:** Optional client-server transport (FEATURES.md differentiator)

**Avoids:** Pitfall 6 (`Channel:demand()` banned in main thread), Pitfall 7 (serialize string event names not integer fragment IDs)

### Phase 7: Example Game

**Rationale:** The example game is the integration test for the entire framework. It must use every core system and at least the input, asset, and collision plugins. It cannot be started until Phases 1-5 are complete. This is the gate for v1.

**Delivers:** A working game in `examples/<game>/` that demonstrates the full plugin lifecycle, proves the framework is genre-agnostic, and serves as developer onboarding documentation.

**Addresses:** Example game (FEATURES.md table stakes — required for v1 claim)

**Avoids:** Pitfall 5 (example game uses generic placeholder concepts, not FactoryGame concepts)

### Phase Ordering Rationale

- Phases 1-2 are strictly sequential and cannot be parallelized. Core infrastructure must be stable before the canonical example can be written, and the canonical example must exist before any plugin is developed against it.
- Phases 3-5 are ordered by integration complexity (simple to complex) and by dependency (assets before example game, collision before example game). Input is independent of assets and collision.
- Phase 6 (transport) is explicitly optional and can be deferred or skipped depending on game requirements. Placing it before the example game allows the example to optionally demonstrate dual-world architecture.
- Phase 7 (example game) is the integration gate. It cannot move earlier.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1 (Core Infrastructure):** The deferred bus re-entrancy guard implementation is not yet verified against edge cases in evolved.lua's query iteration — worth a spike before committing to the design.
- **Phase 6 (Transport):** Fragment ID thread divergence (Pitfall 7) has a clear prevention strategy but the exact module load ordering in love.thread entry points needs validation during implementation.

Phases with standard patterns (skip research-phase):
- **Phase 2 (Canonical Example):** Pattern is codified in CLAUDE.md and `examples/canonical_plugin.lua`; straightforward to execute.
- **Phase 3 (Input):** baton is well-documented; plugin integration is straightforward.
- **Phase 4 (Asset Pipeline):** Lily and Runtime-TextureAtlas have documented APIs; pitfalls are known and prevention strategies are clear.
- **Phase 5 (Collision):** slick and shash are well-understood; integration pattern is standard service registration.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core stack (evolved.lua 1.10.0, binser 0.0-8, Love2D 11.5, selene 0.27.1, stylua 0.20.0) verified directly from vendored files and CI config. Unvendored library recommendations from PROJECT.md curation — MEDIUM for those. |
| Features | HIGH | Derived from CLAUDE.md (architectural rules) and PROJECT.md (design decisions) — both are first-party sources. Ecosystem comparison from community knowledge — MEDIUM for that portion. |
| Architecture | HIGH | Architecture is already partially implemented. Findings are from direct codebase analysis of `src/core/` files. Layer structure and component responsibilities are grounded in existing code, not speculation. |
| Pitfalls | HIGH | Critical pitfalls derived from codebase analysis and evolved.lua singleton behavior — well-understood failure modes. Moderate and minor pitfalls from Love2D threading domain knowledge. |

**Overall confidence:** HIGH

### Gaps to Address

- **Unvendored library versions:** STACK.md lists 11 libraries to vendor as "latest" — actual versions should be pinned when each library is vendored. No blocking issue for planning.
- **Plugin dependency graph completeness:** The architecture validator currently uses regex-based analysis. Known false negatives (dynamic requires, indirect cross-plugin access via services) are documented in Pitfall 9 but the full scope of gaps is unknown. Treat validator as first line of defense.
- **Transport phase scope:** Whether Phase 6 (transport) belongs in v1 or v2 depends on whether the example game needs dual-world demonstration. This decision should be made during requirements definition for the example game phase.
- **galaxy A50 performance floor:** The project names a specific Android device (Galaxy A50) as the performance target. No profiling benchmarks exist yet. AppleCake integration in developer tools will be needed to validate performance on this target before v1 ships.

---

## Sources

### Primary (HIGH confidence)
- `lib/evolved.lua` header — evolved.lua 1.10.0 version confirmation
- `lib/binser.lua` header — binser 0.0-8 version confirmation
- `conf.lua` — Love2D 11.5 target
- `.github/workflows/ci.yml` — selene 0.27.1, stylua 0.20.0, CI pipeline structure
- `CLAUDE.md` — architectural rules, enforcement model, naming conventions
- `src/core/bus.lua`, `src/core/worlds.lua`, `src/core/registry.lua`, `src/core/transport.lua`, `src/core/context.lua`, `src/core/components.lua` — direct codebase analysis for architecture and pitfalls
- `scripts/validate_architecture.lua` — architecture enforcement implementation
- `.planning/PROJECT.md` — project design decisions and library selections

### Secondary (MEDIUM confidence)
- Love2D ecosystem library analysis — feature landscape survey
- Love2D community conventions — plugin pattern norms
- evolved.lua ECS patterns — singleton behavior and tag-based isolation
- Love2D threading and channel documentation — transport pitfalls

### Tertiary (LOW confidence)
- Unvendored library ecosystem knowledge (batteries, baton, slick, shash, Lily, etc.) — recommendations are from PROJECT.md curation, actual API details need validation when vendoring

---
*Research completed: 2026-03-01*
*Ready for roadmap: yes*
