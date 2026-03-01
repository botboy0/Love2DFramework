# Research Summary

**Project:** FactoryGame (Love2D)
**Researched:** 2026-03-01

---

## Key Findings

### Stack
- **selene** for linting (not luacheck — extensible, custom architectural rules via TOML std defs)
- **stylua** for formatting (only viable option)
- **busted** for testing (lifecycle hooks needed for ECS setup/teardown)
- **GitHub Actions** for CI with hard-block gates
- **evolved.lua** ECS, **raw ENet** networking, **bitser/binser** serialization (carried forward)
- All game libs vendored under `lib/`; dev tools via binary downloads + luarocks

### Table Stakes
- Global usage denied via selene — only `love`, `world`, `eventBus`, `registry` whitelisted
- Pre-commit hooks running selene + stylua on every commit
- CI pipeline: lint → test → build, hard block on failure
- Plugin registration API with single `ctx` argument
- Deferred-dispatch event bus (queue + flush per tick, re-entrancy guard)
- Plugin isolation tests (each plugin loads alone, passes all tests)
- CLAUDE.md with architectural rules before any game code

### Watch Out For
1. **ECS erosion** — logic leaking into helpers/callbacks instead of systems (PRIMARY RISK)
2. **AI architectural drift** — each file reasonable, cumulative drift over 50+ files
3. **Global state coupling** — `_G` tables becoming implicit plugin interfaces
4. **Synchronous event chains** — nested emit→handler→emit causing stack overflows
5. **Android performance gap** — desktop masks issues hidden by JIT; test on mobile weekly
6. **Schema migration** — ECS-first persistence needs version + migration from day one
7. **love.thread deadlock** — `channel:demand()` without timeout blocks forever
8. **Lint bypass habits** — too-strict rules too early → `-- selene: allow` everywhere

### Architecture Summary
- Client-server always (love.thread for solo, ENet for multiplayer)
- Server authoritative; client is thin renderer + prediction
- Dual ECS worlds (server simulation + client rendering)
- Plugin pattern: each feature registers via `plugin:init(ctx)` — components, systems, event handlers
- Deferred-dispatch event bus prevents synchronous chains
- Build order: DevOps (Layer 0) → Core infra → Core plugin → World → Player → Features

### Critical Risk
**bitser on Android**: must verify interpreted Lua path works on Android Love2D early. Fallback: pure-Lua MessagePack.

---

## Implications for Requirements

1. **Phase 1 must be DevOps** — architectural drift was the #1 failure mode last time
2. **Deferred event bus is non-negotiable** — prevents the synchronous chain pitfall
3. **Plugin isolation tests are table stakes** — each feature must work alone
4. **Canonical plugin example** should exist before any game plugin is written
5. **Tiered lint severity** — start with warnings, escalate to errors per milestone
6. **CLAUDE.md + architecture rules** in context for all AI generation

---

## Build Order Recommendation

```
Phase 1: DevOps Foundation (BLOCKING)
  selene, stylua, busted, pre-commit, CI, CLAUDE.md, architecture rules

Phase 2: Core Infrastructure
  EventBus, PluginRegistry, ECS worlds, love.thread transport, ctx object
  Canonical plugin example + isolation test template

Phase 3: World + Player
  Chunk manager, world gen, tile renderer, player plugin, input, camera

Phase 4: Game Features (Age 0)
  Survival, crafting, notebook, combat — each as isolated plugin

Phase 5: Integration + Polish
  Age 0 full loop, save/load, mobile testing, performance
```

---

*Research synthesis complete: 2026-03-01*
