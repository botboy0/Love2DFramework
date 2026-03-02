# Roadmap: Love2D Framework

## Overview

The framework ships in seven sequential phases, each delivering a complete, testable layer. Phase 1 builds the entire core contract (event bus, ECS worlds, plugin registry, context object, transport) — nothing else can be written until this layer is stable and tested. Phase 2 codifies the canonical plugin pattern and test harness before any feature plugin exists. Phases 3-5 layer feature plugins (input, assets, collision) on top of the proven core. Phase 6 adds developer tooling that ships only in dev builds. Phase 7 closes with documentation that enables a new developer to clone the repo and build a game without asking questions. Every phase gate is a passing CI pipeline.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Core Infrastructure** - Event bus, ECS worlds, plugin registry, context object, and optional transport — the complete framework contract
- [x] **Phase 2: Plugin Infrastructure** - Canonical plugin example, test harness, and architecture validator checks that make the core contract enforceable (completed 2026-03-02)
- [x] **Phase 3: Input Plugin** - Unified keyboard/gamepad/touch input via baton, registered as a standard framework plugin (completed 2026-03-02)
- [x] **Phase 4: Asset Pipeline** - Async asset loading and texture atlas packing via Lily and Runtime-TextureAtlas (completed 2026-03-02)
- [ ] **Phase 5: Collision Plugin** - Polygon/circle/AABB collision and broad-phase spatial queries via slick and shash
- [ ] **Phase 6: Developer Tools** - Profiling and debug UI for development builds only
- [ ] **Phase 7: Documentation** - API docs and getting-started guide sufficient for a developer to build their first plugin

## Phase Details

### Phase 1: Core Infrastructure
**Goal**: A developer can register a plugin and have it receive a working `ctx` with a live event bus and ECS world
**Depends on**: Nothing (first phase)
**Requirements**: CORE-01, CORE-02, CORE-03, CORE-04, CORE-05, CORE-06, CORE-07, CORE-08, CORE-09, CORE-10
**Success Criteria** (what must be TRUE):
  1. A plugin registered in `plugin_list.lua` receives a `ctx` table containing `worlds`, `bus`, `config`, and `services` when `love.load` runs
  2. Emitting an event inside `bus:on()` handler logs a warning and discards the emission — the flush does not recurse
  3. Events emitted during `update()` are not delivered until `bus:flush()` is called — handlers see no events mid-update
  4. An entity spawned via `worlds` helpers exists in the correct world; raw `evolved.spawn()` is not reachable from plugin code
  5. Shutting down triggers `plugin:shutdown()` on all registered plugins in reverse boot order
**Plans**: 4 plans in 3 waves

Plans:
- [x] 01-01-PLAN.md — Worlds single-world mode + components.lua ships empty (Wave 1)
- [x] 01-02-PLAN.md — Bus error_mode + Transport NullTransport stub (Wave 1)
- [x] 01-03-PLAN.md — Context assembly (transport, auto-bridge, config) + Registry error_mode/side enforcement (Wave 2)
- [x] 01-04-PLAN.md — main.lua wiring (love.quit, transport flush) + canonical plugin update (Wave 3)

### Phase 2: Plugin Infrastructure
**Goal**: The canonical plugin pattern is codified in a reference file and every plugin can be loaded and tested in isolation without sibling plugins
**Depends on**: Phase 1
**Requirements**: PLUG-01, PLUG-02, PLUG-03, PLUG-04, PLUG-05
**Success Criteria** (what must be TRUE):
  1. `examples/canonical_plugin.lua` loads cleanly and demonstrates component registration, system registration, and event handling with no game-specific concepts
  2. A test using `tests/helpers/plugin_harness.lua` that accesses an undeclared service dependency fails with a clear error message
  3. Running the architecture validator on a plugin file containing `evolved.spawn(` or `evolved.id(` produces a CI failure with the offending line identified
  4. The architecture validator flags a `ctx.services:get("X")` call that is not listed in the plugin's declared `deps`
**Plans**: 3 plans in 2 waves

Plans:
- [x] 02-01-PLAN.md — Canonical plugin config usage + harness dep enforcement proxy (Wave 1)
- [x] 02-02-PLAN.md — Validator raw ECS call detection + verbose flag + error/warning separation (Wave 1)
- [x] 02-03-PLAN.md — Validator undeclared service dependency cross-reference (Wave 2)

### Phase 3: Input Plugin
**Goal**: Game code can query player input actions without knowing whether the source is keyboard, gamepad, or touch
**Depends on**: Phase 2
**Requirements**: INPT-01, INPT-02, INPT-03
**Success Criteria** (what must be TRUE):
  1. An action defined in the input config (e.g., `"jump"`) returns a pressed state regardless of whether the trigger is a keyboard key, gamepad button, or touch region
  2. The input plugin boots and shuts down via the standard `plugin:init(ctx)` / `plugin:shutdown()` lifecycle without special-casing in `main.lua`
  3. A test using the plugin harness can exercise input state without a physical device attached
**Plans**: 2 plans in 2 waves

Plans:
- [ ] 03-01-PLAN.md — Registry update_all(dt) + vendor baton library (Wave 1)
- [ ] 03-02-PLAN.md — Input plugin (init.lua, touch_regions.lua, main.lua wiring, plugin_list) (Wave 2)

### Phase 4: Asset Pipeline
**Goal**: Assets load without frame hitches and draw calls are minimized by atlas packing — on mobile targets
**Depends on**: Phase 2
**Requirements**: ASST-01, ASST-02, ASST-03, ASST-04
**Success Criteria** (what must be TRUE):
  1. Requesting an asset load does not block the main thread — the game continues updating while assets load in the background
  2. Sprites packed into a texture atlas at startup are drawn from a single atlas texture, not individual files
  3. The atlas packing step rejects any atlas configuration that would exceed 4096x4096 pixels, with a clear error message
  4. A Lily completion callback emits a bus event — it does not directly spawn entities or mutate ECS state
**Plans**: 4 plans in 4 waves

Plans:
- [x] 04-01-PLAN.md — Vendor Lily + RTA, manifest parser, drawable wrapper (Wave 1)
- [x] 04-02-PLAN.md — Asset loader (Lily wrapper) + atlas builder (RTA wrapper) (Wave 2)
- [x] 04-03-PLAN.md — Asset plugin init.lua + plugin_list wiring (Wave 3)
- [ ] 04-04-PLAN.md — Gap closure: silence test stdout noise (harness, bus, validator) (Wave 4)

### Phase 5: Collision Plugin
**Goal**: Game code can detect collisions and query nearby entities without implementing any spatial math
**Depends on**: Phase 4
**Requirements**: COLL-01, COLL-02, COLL-03
**Success Criteria** (what must be TRUE):
  1. A moving entity with a slick collider slides along wall geometry instead of stopping or passing through
  2. A proximity query via `ctx.services:get("spatial")` returns all entities within a radius without iterating every entity in the world
  3. The spatial query service is declared as a plugin dependency — a plugin that calls it without declaring it fails the architecture validator
**Plans**: TBD

Plans:
- [ ] 05-01: TBD

### Phase 6: Developer Tools
**Goal**: A developer can profile frame performance and inspect runtime state without shipping those tools in game builds
**Depends on**: Phase 1
**Requirements**: DEVT-01, DEVT-02
**Success Criteria** (what must be TRUE):
  1. Enabling the profiler produces a Perfetto-compatible trace file that shows per-system frame timing without modifying game plugin code
  2. The debug UI (Slab) renders development-time overlays and is excluded from non-debug builds — game builds do not load Slab
**Plans**: TBD

Plans:
- [ ] 06-01: TBD

### Phase 7: Documentation
**Goal**: A developer who has never seen this codebase can clone it, read the docs, and register a working plugin without asking questions
**Depends on**: Phase 2
**Requirements**: DOCS-01, DOCS-02
**Success Criteria** (what must be TRUE):
  1. A developer can look up the plugin registry API, event bus API, ECS world API, and context object API in one place without reading source files
  2. Following the getting-started guide step-by-step produces a plugin that boots, receives `ctx`, emits a bus event, and passes CI — with zero prior framework knowledge
**Plans**: TBD

Plans:
- [ ] 07-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7
Note: Phase 6 (Developer Tools) depends only on Phase 1 and Phase 7 (Documentation) depends only on Phase 2 — both can begin as soon as their dependencies are met without waiting for all prior phases.

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Core Infrastructure | 4/4 | Complete | 2026-03-02 |
| 2. Plugin Infrastructure | 3/3 | Complete   | 2026-03-02 |
| 3. Input Plugin | 2/2 | Complete   | 2026-03-02 |
| 4. Asset Pipeline | 3/4 | In progress | - |
| 5. Collision Plugin | 0/? | Not started | - |
| 6. Developer Tools | 0/? | Not started | - |
| 7. Documentation | 0/? | Not started | - |
