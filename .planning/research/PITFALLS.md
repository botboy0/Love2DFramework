# Domain Pitfalls

**Domain:** Love2D game framework (ECS + event bus + plugin registry)
**Researched:** 2026-03-01
**Confidence:** HIGH — derived from direct codebase analysis and domain knowledge

---

## Critical Pitfalls

### Pitfall 1: evolved.lua Is a Global Singleton — Not a Multi-Instance ECS

**What goes wrong:** `evolved.lua` maintains global state. There are no separate "world instances." The framework works around this with tag-based isolation (`ServerTag` / `ClientTag`), but every new scope (UI entities, pooled particles) risks polluting queries if tag discipline breaks down.

**Warning signs:**
- Any `evolved.spawn()` call not going through `worlds:spawn_server()` or `worlds:spawn_client()`
- Queries without a world tag (`ServerTag` or `ClientTag`)

**Prevention:**
- All entity creation must go through `worlds` helpers — never raw `evolved.spawn()`
- Architecture validator should flag raw `evolved.spawn(` calls in plugin files
- Every query must include at least one world tag

**Phase mapping:** Core Infrastructure — before any plugin writes queries.

---

### Pitfall 2: Event Bus Re-Entrancy Silently Discards Events

**What goes wrong:** If `bus:emit()` is called during `bus:flush()`, the event is silently discarded with a log warning. Any handler that emits loses that event entirely.

**Warning signs:**
- `bus:emit()` inside a `bus:on(...)` callback
- Handler code calling helpers that internally emit
- Log output: `[Bus] Re-entrancy guard: emit(...) called during flush`

**Prevention:**
- Handlers may NOT emit events. All emissions happen in systems during `update()`, before `bus:flush()`
- Canonical plugin example should include a comment: `-- NOTE: Do not call bus:emit() inside this handler`
- Test the bus with a re-emitting handler and assert the warning is logged

**Phase mapping:** Core Infrastructure — document during bus implementation.

---

### Pitfall 3: Components Defined Per-Plugin Instead of Centrally

**What goes wrong:** `src/core/components.lua` is the single source of truth for fragment IDs. If a plugin defines fragments locally via `evolved.id()`, those IDs conflict or become invisible to other systems.

**Warning signs:**
- Any `evolved.id()` call outside `src/core/components.lua` or `src/core/worlds.lua`
- Component names in plugin files matching names in `src/core/components.lua`

**Prevention:**
- Architecture validator must flag `evolved.id(` calls in plugin files
- Plugins consume components from `src.core.components`, never define shared ones
- Exception: purely internal marker tags documented as plugin-private

**Phase mapping:** Core Infrastructure — add validator check before first plugin.

---

### Pitfall 4: Plugin Order-Dependent Behavior Without Declared Dependencies

**What goes wrong:** Registry boots plugins in topological order. A plugin reading a service without declaring the dependency works by coincidence until plugin order changes.

**Warning signs:**
- `ctx.services:get(...)` without corresponding `deps` entry
- Missing `deps` field in `plugin_list.lua` entries

**Prevention:**
- Architecture validator cross-references `ctx.services:get("X")` against declared `deps`
- Plugin harness fails when undeclared services are accessed
- Every `ctx.services:get()` call must comment the required dep

**Phase mapping:** Core Infrastructure — registry + plugin harness.

---

### Pitfall 5: Genre-Agnostic Claims Collapse Under Game-Specific Assumptions

**What goes wrong:** Core infrastructure that encodes FactoryGame-specific concepts — transport hardcoding "player_moved," component registry shipping with `Inventory` or `Crafting`, examples using FactoryGame terminology.

**Warning signs:**
- Components in `src/core/components.lua` beyond geometric primitives and lifecycle tags
- Event names encoding gameplay concepts ("resource_collected", "enemy_spawned")
- Documentation using FactoryGame terminology instead of generic placeholders

**Prevention:**
- `src/core/components.lua` ships with only: Position, Velocity, Size, and world tags
- Transport's `mark_networkable` is explicitly call-by-game — no defaults
- All example code uses generic placeholder names
- End-of-phase review: "would a puzzle game need to remove this?"

**Phase mapping:** Every phase. Genre-agnostic review at end of each infrastructure phase.

---

## Moderate Pitfalls

### Pitfall 6: love.thread Channel Blocking Stalls Main Thread

**What goes wrong:** `Channel:demand()` blocks until a message arrives. One misplaced `demand()` in the main thread freezes the game loop.

**Prevention:**
- Architecture validator flags `Channel:demand()` without a timeout argument
- Rule: `demand()` banned in main-thread code. Use `pop()` + handle nil.

**Phase mapping:** Networking/transport phase.

---

### Pitfall 7: Fragment IDs Differ Across Threads

**What goes wrong:** `love.thread` creates a new Lua state. If modules load in different order, `evolved.id()` allocations shift — same component name resolves to different IDs on each thread. Serialized fragment IDs become wrong component on the other side.

**Prevention:**
- Never serialize evolved fragment IDs across thread boundaries
- Transport must use string event names, not integer IDs
- Load `src.core.components` first in both thread entry points

**Phase mapping:** Networking/transport phase.

---

### Pitfall 8: Stateful Services Bypass ECS Source of Truth

**What goes wrong:** Services closing over mutable state (cache, counter, entity reference) create hidden cross-plugin coupling. The ECS is no longer the single source of truth.

**Prevention:**
- Services expose query accessors only — no mutable fields, no caches
- Add to CLAUDE.md: "Services expose query accessors only. No mutable fields."
- Architecture validator heuristic: service tables with non-function fields are warnings

**Phase mapping:** Core Infrastructure — context/services design.

---

### Pitfall 9: Architecture Validator False Negatives

**What goes wrong:** Regex-based analysis misses dynamic requires, indirect cross-plugin access via services, and Love2D rendering API calls in server systems.

**Prevention:**
- Add checks for `love.graphics`, `love.audio` in `src/server/` files
- Document known gaps in validator header
- Treat validator as first line of defense, not complete guarantee

**Phase mapping:** Ongoing — add checks as new patterns are discovered.

---

## Minor Pitfalls

### Pitfall 10: Plugin Shutdown Not Wired to love.quit

**What goes wrong:** `registry:shutdown()` exists but `love.quit` doesn't call it. Resource leaks on exit.

**Prevention:** Wire `love.quit` handler when registry is implemented. Test it.

**Phase mapping:** Core Infrastructure.

---

### Pitfall 11: Mobile Texture Atlas Size Limits

**What goes wrong:** Mobile GPUs cap at 4096x4096. Desktop works at 16384x16384. Atlas exceeds mobile limit silently.

**Prevention:** Cap packing at 4096x4096. Assert at startup.

**Phase mapping:** Asset pipeline phase.

---

### Pitfall 12: Lily Async Callbacks Spawning Entities Mid-Tick

**What goes wrong:** Lily callbacks fire during `love.update`. Spawning entities mid-query-iteration may corrupt chunk layout.

**Prevention:** Lily callbacks emit bus events only — never spawn directly. Entities spawned next tick by a system.

**Phase mapping:** Asset pipeline phase.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| ECS world management | Pitfall 1: singleton world | Add raw-spawn validator check |
| Event bus | Pitfall 2: emit during flush | Document handler constraint |
| Component registry | Pitfall 3: per-plugin IDs | Add evolved.id() validator check |
| Plugin registry/deps | Pitfall 4: implicit dep order | Harness fails on undeclared access |
| Genre-agnostic review | Pitfall 5: game-specific in core | End-of-phase review question |
| Thread transport | Pitfall 6+7: blocking + ID mismatch | Serialize strings not integers |
| Services API | Pitfall 8: stateful services | Query accessors only rule |
| Asset pipeline | Pitfall 11+12: mobile limits + Lily ordering | Cap atlas; callbacks emit events |

---

## Sources

- Direct codebase analysis: `src/core/bus.lua`, `src/core/worlds.lua`, `src/core/registry.lua`, `src/core/transport.lua`, `src/core/context.lua`, `src/core/components.lua`, `scripts/validate_architecture.lua`
- Project requirements: `.planning/PROJECT.md`
- Domain knowledge of Love2D threading, evolved.lua singleton architecture, Lua global state

---
*Pitfall research for: Love2D Game Framework*
*Researched: 2026-03-01*
