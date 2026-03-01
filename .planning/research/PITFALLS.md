# Domain Pitfalls

**Domain:** Love2D factory game — ECS enforcement, plugin modularity, devops-first, AI-assisted development
**Researched:** 2026-03-01
**Confidence:** MEDIUM-HIGH

---

## Critical Pitfalls

### Pitfall 1: ECS Erosion — Logic Leaking Outside Systems

**What goes wrong:** Game logic accumulates in callbacks, helper modules, or "utility" files instead of ECS systems. A `player.lua` directly mutates position. A `collision_handler` modifies health directly. The ECS becomes a data bag while real logic lives elsewhere.

**Why it happens:** Lua's module system makes it trivially easy to `require` any file and call anything. Under time pressure or AI generation, the path of least resistance bypasses the ECS.

**Consequences:** State split; ECS-first persistence breaks silently; systems can't query state they don't own; testing impossible.

**Prevention:**
- Lint rule detecting direct component mutation outside registered systems
- All game-logic files receive only an ECS world reference
- Code review checklist: "Does this function exist as a registered ECS system?"

**Warning signs:** Files named `*_helper.lua`, `*_manager.lua` with game logic; functions taking raw entity tables outside systems.

**Phase:** Phase 1 (DevOps) — lint rules before any game code

---

### Pitfall 2: Plugin Coupling Through Global State

**What goes wrong:** Plugins communicate via `_G` tables or module-level variables instead of the event bus. `_G.inventory` becomes an implicit interface.

**Prevention:**
- selene `global_usage = "deny"` with strict whitelist
- Plugin `init()` receives only `ctx` — nothing else
- Test: load each plugin alone; all tests must pass
- Grep for `_G.` in plugin code; block PRs

**Warning signs:** `_G.` references; cross-plugin `require`; tests failing in isolation.

**Phase:** Phase 1 — globals rule before plugin scaffolding

---

### Pitfall 3: Event Bus Becoming Synchronous Call Graph

**What goes wrong:** `emit("item:pickup")` triggers `emit("inventory:add")` triggers `emit("recipe:check")` — all synchronously. Stack overflows and frame spikes.

**Prevention:**
- Deferred-dispatch bus: `emit()` queues; `bus:flush()` dispatches once per tick
- Re-entrancy guard: runtime error if `emit()` called inside a handler
- If a feature needs 3+ event hops, redesign

**Warning signs:** Stack traces showing nested fire→handler→fire chains; frame spikes.

**Phase:** Phase 1 — deferred bus designed before any feature uses it

---

### Pitfall 4: love.thread Channel Deadlock

**What goes wrong:** Both threads try to send large payloads simultaneously; `channel:demand()` blocks indefinitely.

**Prevention:**
- Always use `channel:demand(timeout)` with a timeout
- Protocol: server sends snapshots on fixed tick; client sends inputs only
- Sequence numbers; client discards out-of-order packets

**Warning signs:** `channel:demand()` without timeout; client waiting for server response.

**Phase:** Phase 2 — protocol defined before game logic uses it

---

### Pitfall 5: ECS Persistence Breaking on Schema Changes

**What goes wrong:** Components renamed, fields added/removed. Old save files silently fail.

**Prevention:**
- Schema version number in every save from day one
- Migration runner before first save: `migrations/v1_to_v2.lua`
- Component fields have registered defaults; nil on load fills default

**Warning signs:** No `save_version` field; component definitions without defaults.

**Phase:** Phase 1 — version field before first save is written

---

### Pitfall 6: Android Performance Hidden by Desktop

**What goes wrong:** Game runs 60fps on desktop, 15fps on Galaxy A50. LuaJIT disabled on Android.

**Prevention:**
- Android build + AppleCake profiling from early phases
- No table allocation in system update loops
- SpriteBatch from Phase 2 — never "add later"
- Ban `pairs()` in hot paths; use `ipairs()` on sorted arrays

**Warning signs:** System functions creating tables per entity per frame; per-entity `love.graphics.draw()`.

**Phase:** Phase 1 sets up profiling; Phase 2 enforces SpriteBatch

---

## Moderate Pitfalls

### Pitfall 7: Plugin API Inconsistency

**What:** First plugins use `init(world, bus)`, third needs config, fourth needs chunk manager.

**Prevention:** Single context object: `ctx = { world, bus, config, services }`. All plugins receive `ctx` only. Test template validates `init(ctx)` with one argument.

**Phase:** Phase 2 — ctx contract before first plugin

---

### Pitfall 8: ECS Archetype Fragmentation

**What:** Tile entities destroyed/recreated on chunk unload; ECS archetype table fills with holes.

**Prevention:** Tile entities get `Dormant` tag on unload, not destroyed. Reactivate on reload.

**Phase:** Phase 3 (world/chunk system)

---

### Pitfall 9: Lint Rules Too Strict → Bypass Habits

**What:** Every placeholder fails lint. Developers add `-- selene: allow` everywhere.

**Prevention:** Tiered severity: errors (hard block) vs warnings (report only) at start. Promote warnings per milestone. Never suppress without a comment + ticket.

**Phase:** Phase 1 — design tiered rules, not final rules

---

### Pitfall 10: AI-Generated Undeclared Globals

**What:** Generated code creates module-level globals, uses nonexistent `require` paths.

**Prevention:** CLAUDE.md with architecture rules always in context. Pre-commit on ALL files. `validate_architecture.lua` in CI.

**Phase:** Phase 1 — CLAUDE.md before any game code generation

---

### Pitfall 11: Incremental AI Architectural Drift

**What:** Each generated file is locally reasonable. Over 50 files the architecture drifts.

**Prevention:** Include canonical plugin example in every generation prompt. Full architecture audit at milestone boundaries. Architectural fitness tests.

**Phase:** All phases — canonical example from Phase 2; audits at every milestone

---

### Pitfall 12: LuaJIT Assumptions in Server Code

**What:** Server uses FFI or `bit` library; crashes on Android interpreted Lua.

**Prevention:** `jit.off()` in server thread during dev. Never `require('ffi')` in server. Use `bit32` not `bit`. CI includes JIT-disabled test run.

**Phase:** Phase 1 — CI matrix with JIT-disabled

---

## Minor Pitfalls

### Pitfall 13: STI for Infinite World

**What:** STI assumes known map size; breaks with chunk-based infinite world.

**Prevention:** Use STI for tile property metadata only. Custom chunk SpriteBatch renderer.

**Phase:** Phase 2

---

### Pitfall 14: Notebook With Client-Side State

**What:** Discovery state on client creates second source of truth.

**Prevention:** Discovery lives in server ECS only. Client renders; holds no state.

**Phase:** Phase 3

---

### Pitfall 15: O(n^2) Proximity in Ground Crafting

**What:** All items checked against all items every frame.

**Prevention:** Route through shash broad-phase. Run on timer (0.5s), not every frame.

**Phase:** Phase 4

---

## Phase-Specific Warnings

| Phase | Pitfall | Mitigation |
|-------|---------|------------|
| Phase 1: DevOps | Lint too strict → bypass | Tiered severity |
| Phase 1: DevOps | Missing CLAUDE.md → AI drift | CLAUDE.md + canonical before game code |
| Phase 1: DevOps | No JIT-disabled CI | Add to matrix explicitly |
| Phase 2: Plugins | API inconsistency | ctx contract first |
| Phase 2: Plugins | Sync event chains | Deferred bus first |
| Phase 2: Tiles | STI for infinite world | Custom chunk renderer |
| Phase 3: World | Archetype fragmentation | Dormancy pattern |
| Phase 3: Notebook | Client-side state | Server-authoritative |
| Phase 3: Saves | No migration system | Version + runner before first save |
| Phase 4: Crafting | O(n^2) proximity | shash + timer |
| All: AI gen | Drift | Canonical example + audits |
| All: Perf | Android regression | Weekly mobile benchmarks |

---

*Pitfalls research complete: 2026-03-01*
