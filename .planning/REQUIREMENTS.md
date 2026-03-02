# Requirements: Love2D Framework

**Defined:** 2026-03-01
**Core Value:** A framework that enforces clean architecture by default — ECS-only game logic, event-bus-only communication, isolated plugins — so games stay maintainable as they grow.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Core Infrastructure

- [x] **CORE-01**: Plugin registry boots plugins in topological dependency order via `plugin:init(ctx)` API
- [x] **CORE-02**: Plugin registry shuts down plugins in reverse order via `love.quit`
- [x] **CORE-03**: Deferred-dispatch event bus queues events during update and delivers on `bus:flush()`
- [x] **CORE-04**: Event bus re-entrancy guard blocks emissions during flush with a logged warning
- [x] **CORE-05**: ECS world management integrates evolved.lua with tag-based isolation (ServerTag/ClientTag)
- [x] **CORE-06**: Single-world mode works without tags for simple games
- [x] **CORE-07**: Context object `ctx = { worlds, bus, config, services }` passed to all plugins
- [x] **CORE-08**: Shared components defined centrally in `src/core/components.lua` — no `evolved.id()` in plugin files
- [x] **CORE-09**: Optional love.thread channel transport for client-server communication
- [x] **CORE-10**: Explicit plugin manifest (`plugin_list.lua`) — no auto-discovery

### Plugin Infrastructure

- [x] **PLUG-01**: Plugin isolation test harness provides minimal ctx with declared dependencies only
- [x] **PLUG-02**: Canonical plugin example demonstrates component registration, system registration, and event handling
- [x] **PLUG-03**: Architecture validator flags raw `evolved.spawn()` calls in plugin files
- [x] **PLUG-04**: Architecture validator flags `evolved.id()` calls in plugin files
- [x] **PLUG-05**: Architecture validator cross-references `ctx.services:get()` against declared plugin deps

### Input

- [x] **INPT-01**: Unified input plugin wrapping baton for keyboard, gamepad, and touch
- [x] **INPT-02**: Action-based input mapping abstracted from hardware devices
- [x] **INPT-03**: Input plugin registered as standard framework plugin via `plugin:init(ctx)`

### Asset Pipeline

- [ ] **ASST-01**: Async asset loading via Lily prevents frame hitches during loading
- [ ] **ASST-02**: Texture atlas packing via Runtime-TextureAtlas at startup reduces draw calls
- [ ] **ASST-03**: Asset pipeline capped at 4096x4096 atlas size for mobile GPU compatibility
- [ ] **ASST-04**: Lily callbacks emit bus events only — no direct entity spawning mid-tick

### Collision

- [ ] **COLL-01**: Collision detection plugin with slick providing polygon/circle/AABB with slide response
- [ ] **COLL-02**: Broad-phase spatial indexing via shash for efficient proximity queries
- [ ] **COLL-03**: Spatial query service exposed via `ctx.services` — stateless query accessors only

### Developer Tools

- [ ] **DEVT-01**: Profiling integration with AppleCake for Perfetto visualization
- [ ] **DEVT-02**: Debug UI via Slab for development-time tooling (not shipped in game builds)

### Documentation

- [ ] **DOCS-01**: API documentation covering plugin registration, event bus, ECS world, and context
- [ ] **DOCS-02**: Getting-started guide sufficient for a developer to create their first plugin

## v2 Requirements

Deferred to future release.

### Scene Management

- **SCNE-01**: Scene/state management with push/pop stack (Roomy-style)
- **SCNE-02**: Scene transitions with lifecycle hooks

### Camera & Resolution

- **CAMR-01**: Camera system integration (gamera) with viewport, pan, zoom
- **CAMR-02**: Fixed internal resolution scaling (Push) for pixel-perfect rendering

### Networking

- **NETW-01**: Remote multiplayer via raw ENet
- **NETW-02**: Server-authoritative state synchronization
- **NETW-03**: Client-side movement prediction with server reconciliation

### Additional Libraries

- **LIBR-01**: Tilemap loading via STI (Tiled .tmx support)
- **LIBR-02**: Tweening/animation via Flux

## Out of Scope

| Feature | Reason |
|---------|--------|
| Game-specific logic (inventory, crafting, combat) | Domain-specific; makes framework non-genre-agnostic |
| Custom UI system | Opinionated; every game has different UI needs |
| Hot-reload | Defeats static analysis; creates inconsistent ECS state |
| Custom ECS implementation | evolved.lua is battle-tested; replacing means full rewrite |
| Internet multiplayer (v1) | NAT traversal, authority models — separate milestone |
| Asset hot-swap at runtime | Breaks reproducibility; conflicts with atlas pre-packing |
| Example game | Deferred — framework ships as infrastructure, games built on top |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CORE-01 | Phase 1 | Complete |
| CORE-02 | Phase 1 | Complete |
| CORE-03 | Phase 1 | Complete |
| CORE-04 | Phase 1 | Complete |
| CORE-05 | Phase 1 | Complete |
| CORE-06 | Phase 1 | Complete |
| CORE-07 | Phase 1 | Complete |
| CORE-08 | Phase 1 | Complete |
| CORE-09 | Phase 1 | Complete |
| CORE-10 | Phase 1 | Complete |
| PLUG-01 | Phase 2 | Complete |
| PLUG-02 | Phase 2 | Complete |
| PLUG-03 | Phase 2 | Complete |
| PLUG-04 | Phase 2 | Complete |
| PLUG-05 | Phase 2 | Complete |
| INPT-01 | Phase 3 | Complete |
| INPT-02 | Phase 3 | Complete |
| INPT-03 | Phase 3 | Complete |
| ASST-01 | Phase 4 | Pending |
| ASST-02 | Phase 4 | Pending |
| ASST-03 | Phase 4 | Pending |
| ASST-04 | Phase 4 | Pending |
| COLL-01 | Phase 5 | Pending |
| COLL-02 | Phase 5 | Pending |
| COLL-03 | Phase 5 | Pending |
| DEVT-01 | Phase 6 | Pending |
| DEVT-02 | Phase 6 | Pending |
| DOCS-01 | Phase 7 | Pending |
| DOCS-02 | Phase 7 | Pending |

**Coverage:**
- v1 requirements: 29 total
- Mapped to phases: 29
- Unmapped: 0

---
*Requirements defined: 2026-03-01*
*Last updated: 2026-03-02 after 02-01 completion — PLUG-01, PLUG-02 marked complete*
