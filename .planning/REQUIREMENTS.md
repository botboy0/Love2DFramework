# Requirements: FactoryGame

**Defined:** 2026-03-01
**Core Value:** Discovery-driven progression loop — every new material reveals recipe hints, pulling the player deeper into exploration and automation.

## v1 Requirements

Requirements for initial release. DevOps + infrastructure foundation — no game code yet.

### DevOps

- [x] **DEV-01**: selene linting with `global_usage = "deny"` and custom std definition whitelisting only `love`, `world`, `eventBus`, `registry`
- [x] **DEV-02**: stylua formatting enforced on all Lua source files
- [x] **DEV-03**: Pre-commit hooks running selene + stylua; hard-block non-conforming commits
- [x] **DEV-04**: GitHub Actions CI pipeline: lint → test → build; hard-block on failure
- [x] **DEV-05**: busted test framework with plugin test harness (Phase 1: stub world/bus/registry with plain Lua tables; Phase 2: full ECS lifecycle hooks via evolved.lua)
- [x] **DEV-06**: CLAUDE.md with architectural enforcement rules (ECS-only logic, event-bus-only communication, plugin isolation)
- [x] **DEV-07**: Architecture validator script (`validate_architecture.lua`) in CI checking for globals, cross-plugin imports, client-side game logic

### Core Infrastructure

- [x] **INFRA-01**: Deferred-dispatch event bus with queue + flush-per-tick and re-entrancy guard
- [ ] **INFRA-02**: Plugin registry with standard `plugin:init(ctx)` API; `ctx = { world, bus, config, services }`
- [x] **INFRA-03**: Dual evolved.lua ECS worlds (server simulation + client rendering)
- [ ] **INFRA-04**: love.thread channel transport for client-server communication (solo mode)
- [x] **INFRA-05**: Context object pattern — single `ctx` passed to all plugins
- [ ] **INFRA-06**: Plugin isolation test template — each plugin loadable and testable without sibling plugins
- [ ] **INFRA-07**: Canonical plugin example (`examples/canonical_plugin.lua`) maintained as reference implementation

## v2 Requirements

Deferred to next milestone. Game features (Age 0: beach to copper tool).

### World

- **WORLD-01**: Chunk-based infinite procedural world generation (server-side)
- **WORLD-02**: 16x16 tile SpriteBatch rendering with spatial culling (client-side)
- **WORLD-03**: Chunk load/unload streaming from server to client

### Player

- **PLAYER-01**: Player entity with 8-dir movement, server-authoritative
- **PLAYER-02**: Inventory and hotbar system
- **PLAYER-03**: Melee and ranged combat
- **PLAYER-04**: Place and break tiles/blocks
- **PLAYER-05**: Client-side movement prediction with server reconciliation

### Gathering

- **GATHER-01**: Pick up loose items from ground (stones, sticks, berries)
- **GATHER-02**: Chop trees for wood, mine rocks for stone
- **GATHER-03**: Tool durability system

### Crafting

- **CRAFT-01**: Ground crafting — place items near each other to combine
- **CRAFT-02**: Recipe registry with discovery (notebook system)
- **CRAFT-03**: Notebook UI showing discovered recipes and `???` hints

### Survival

- **SURV-01**: Hunger and thirst meters
- **SURV-02**: Cooking system (campfire)
- **SURV-03**: Health, damage, death/respawn

### Combat

- **COMBAT-01**: Hostile creatures at zone edges
- **COMBAT-02**: Simple enemy AI (patrol, chase, attack)
- **COMBAT-03**: Basic weapons and armor from crafted materials

### Smelting

- **SMELT-01**: Pit furnace construction
- **SMELT-02**: Charcoal production
- **SMELT-03**: Copper ore smelting → copper ingot → copper tools

### Persistence

- **SAVE-01**: ECS-first save/load via binser serialization
- **SAVE-02**: Schema versioning with migration runner

## Out of Scope

| Feature | Reason |
|---------|--------|
| 3D rendering | Start 2D; ECS swap later |
| Day/night cycle | Add later if it adds value |
| Age 1+ content | v1 is devops + infrastructure only |
| Multiplayer networking (remote) | Architecture supports it; defer implementation |
| Conveyor belts / pipes | Age 3+ content; not in Age 0 |
| Modding / scripting API | Premature; attack surface for arch violations |
| Hot-reload system | Defeats static analysis; use fast restart |
| Dynamic plugin loading | Fixed set at boot; dynamic creates untestable permutations |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEV-01 | Phase 1 | Complete |
| DEV-02 | Phase 1 | Complete |
| DEV-03 | Phase 1 | Complete |
| DEV-04 | Phase 1 | Complete |
| DEV-05 | Phase 1 | Complete |
| DEV-06 | Phase 1 | Complete |
| DEV-07 | Phase 1 | Complete |
| INFRA-01 | Phase 2 | Complete |
| INFRA-02 | Phase 2 | Pending |
| INFRA-03 | Phase 2 | Complete |
| INFRA-04 | Phase 2 | Pending |
| INFRA-05 | Phase 2 | Complete |
| INFRA-06 | Phase 2 | Pending |
| INFRA-07 | Phase 2 | Pending |

**Coverage:**
- v1 requirements: 14 total
- Mapped to phases: 14
- Unmapped: 0

---
*Requirements defined: 2026-03-01*
*Last updated: 2026-03-01 after 01-02 completion (DEV-03, DEV-05)*
