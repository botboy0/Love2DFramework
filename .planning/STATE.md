---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: unknown
last_updated: "2026-03-02T19:50:37.115Z"
progress:
  total_phases: 4
  completed_phases: 4
  total_plans: 13
  completed_plans: 13
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-01)

**Core value:** A framework that enforces clean architecture by default — ECS-only game logic, event-bus-only communication, isolated plugins — so games stay maintainable as they grow.
**Current focus:** Phase 4 — Asset Pipeline

## Current Position

Phase: 4 of 7 (Asset Pipeline)
Plan: 4 of 4 in current phase (04-04 complete)
Status: Phase 4 complete
Last activity: 2026-03-02 - Completed 04-04: Silenced busted stdout noise (harness print stub, Bus log suppressor, Validator silent mode)

Progress: [█████████░] ~80%

## Performance Metrics

**Velocity:**
- Total plans completed: 8
- Average duration: ~4 min/plan
- Total execution time: ~30 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-core-infrastructure | 4 | ~11 min | ~2.75 min |
| 02-plugin-infrastructure | 3 | ~13 min | ~4.3 min |
| 03-input-plugin (partial) | 2 | ~10 min | ~5 min |
| 04-asset-pipeline | 3 | ~13 min | ~4.3 min |

**Recent Trend:**
- Last 5 plans: 03-01, 03-02, 04-01, 04-02
- Trend: On track — Phase 4 plan 2 complete

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Init]: DevOps stack is complete and carried forward — Phase 1 starts on framework code directly
- [Init]: Example game deferred (moved to Out of Scope for v1) — Phase 7 is Documentation, not a game
- [Init]: Transport (CORE-09) is in Phase 1 Core Infrastructure alongside bus/registry/worlds
- [01-01]: Worlds.create() defaults to single-world (no tag isolation); dual-world is explicit opt-in via { dual = true }
- [01-01]: components.lua ships empty (return {}) — framework is genre-agnostic; games define their own fragment IDs
- [01-01]: Canonical plugin exposes fragment IDs on module table so specs can spawn matching entities without importing empty components.lua
- [01-02]: Bus strict mode uses pcall + error(err, 0) re-raise so _flushing is always reset before error propagates
- [01-02]: Bus.new(fn) backward compat preserved — function arg treated as log with tolerant mode; opts table is new preferred form
- [01-02]: Transport.Null exposed on Transport table (not separate module) — callers require only src.core.transport
- [01-03]: Auto-bridge always installed on bus:emit() — NullTransport.is_networkable always returns false, so no special-casing needed
- [01-03]: transport = true requires opts.transport_channels; channel creation belongs in main.lua, not Context.new
- [01-03]: resolve_error_mode() duplicated in context.lua and registry.lua (acceptable until a third caller appears)
- [01-03]: Registry tolerant boot uses pcall(entry.module.init, entry.module, ctx) — method syntax cannot be pcall'd cleanly
- [01-03]: Side enforcement uses is_dual_world() duck-type check (worlds.server + worlds.client) — no worlds mode flag needed
- [01-04]: love.quit guard: if _registry and _ctx — safe for quit-before-load
- [01-04]: Transport flush ordering: receive_all (inbound->bus queue) before bus:flush before transport:flush (outbound)
- [01-04]: _config local in main.lua — games override here or in conf.lua; not loaded from file
- [01-04]: canonical_plugin.lua uses local fragments; single-world compatibility via if ctx.worlds.server duck-type check
- [02-01]: Harness proxy intercepts :get() only; register() and other methods delegate transparently to real services via __index
- [02-01]: error_mode defaults to "strict" inline in harness — no shared resolve_error_mode (no third caller yet)
- [02-01]: Proxy only installed when opts.allowed_deps provided — all existing harness callers unaffected
- [02-02]: detect_raw_ecs_calls uses ^src/plugins/ path guard — examples/, src/core/, lib/ excluded naturally
- [02-02]: Alias detection flags only the assignment line, not subsequent alias calls — avoids false positives with variable shadowing
- [02-02]: Validator.run() now returns (error_count, warning_count) — breaking change from single total; integration test updated
- [02-02]: format_verbose() stores _verbose_str on violation objects; print_section checks field before falling back to formatter
- [Phase 02-plugin-infrastructure]: detect_undeclared_service_deps takes plugin_dir (not path) — must cross-reference init.lua deps against all files in the directory
- [Phase 02-plugin-infrastructure]: parse_declared_deps is local (not Validator.method) — only detect_undeclared_service_deps needs it
- [Phase 02-plugin-infrastructure]: Both dep_parse_errors and service dep errors are CI-blocking — missing declaration is as bad as undeclared call
- [03-01]: update_all follows exact tolerant/strict pcall pattern from boot() — symmetry makes the code predictable
- [03-01]: Pre-boot update_all() is safe no-op — empty _boot_order means zero iterations, no guard branch needed
- [03-01]: main.lua ordering: update_all(dt) -> receive_all -> bus:flush -> transport:flush — plugin updates emit events flushed same frame
- [03-02]: Service functions are plain functions (not :methods) — callers use svc.is_down("jump") without colon
- [03-02]: touch_regions.lua uses _get_dimensions() injection for test isolation (no love.graphics in tests)
- [03-02]: .busted lpath = './?/init.lua' added to enable require('src.plugins.X') finding plugin init.lua files
- [03-02]: love.touch nil-guarded in get_touch_points — love global may not exist in test environment
- [04-01]: RTA is multi-file: vendored to lib/RuntimeTextureAtlas/ with lib/TA.lua as re-export wrapper (require("lib.RuntimeTextureAtlas"))
- [04-02]: AssetLoader uses loadMulti for both load_manifest and load_single — consistent callback interface, simpler pending tracking
- [04-02]: is_complete() tracks _manifest_complete boolean (set in onComplete) and _pending_singles counter — clear state model
- [04-02]: AtlasBuilder canvas retrieval: try atlas:getCanvas() first, fall back to atlas._canvas field (handles both real RTA and stubs)
- [04-02]: Auto-split algorithm: greedy descending-area bin-fill produces sub-groups named group_1, group_2, etc.
- [04-01]: Manifest.parse returns (load_requests, groups) tuple — groups maps group_name -> [keys] for atlas-eligible images only
- [04-01]: Image group derivation: atlas=false -> nil (standalone), explicit group= -> override, else derive from penultimate path segment
- [04-01]: DrawableWrapper injectable via opts.draw_fn and opts.get_dimensions_fn — no love.graphics at module load time
- [04-01]: Test spy helper uses setmetatable __call (not bare function) to allow field assignment in Lua 5.1
- [04-03]: asset:ready deferred to update() — batch_complete handler fires during flush(), direct emit discarded by bus re-entrancy guard
- [04-03]: DI via second opts arg to init() for test isolation — same pattern as touch_regions.lua _get_dimensions injection
- [04-03]: block_depth replaces function_depth in validator detect_globals — counts ALL block-opening keywords (function, if, for, while, repeat, do) to avoid false positives from nested block ends
- [04-04]: print stub uses _G.print save/restore (not spy) in tolerant-mode harness spec — simpler, busted-agnostic
- [04-04]: log() local helper in Validator.run() + if not silent guards at all call sites — preserves print_section/print_warning_section signatures unchanged
- [04-04]: Script entry-point prints left unsuppressed — CLI output vs library output separation is intentional

### Pending Todos

None yet.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 1 | Fix ROADMAP plugin:quit() → plugin:shutdown() naming | 2026-03-02 | f004fce | [1-fix-roadmap-plugin-quit-to-plugin-shutdo](./quick/1-fix-roadmap-plugin-quit-to-plugin-shutdo/) |
| 2 | Implement validate_architecture --fix flag for missing test files | 2026-03-02 | 22d9f12 | [2-implement-validate-architecture-fix-flag](./quick/2-implement-validate-architecture-fix-flag/) |
| 3 | Create a simple stacker game using the framework | 2026-03-02 | f3790d2 | [3-create-a-simple-stacker-game-using-the-f](./quick/3-create-a-simple-stacker-game-using-the-f/) |

### Blockers/Concerns

- [Research flag] Phase 1: Deferred bus re-entrancy guard edge cases with evolved.lua query iteration — worth a spike before committing to the design
- [Research flag] Phase 6 (if transport is demonstrated): Fragment ID thread divergence in love.thread entry points needs validation during implementation

## Session Continuity

Last session: 2026-03-02
Stopped at: Completed quick task 3 — Stacker game plugin (Registry:draw_all, ECS fragments, full CI passing)
Resume file: None
