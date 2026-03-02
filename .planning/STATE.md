---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: unknown
last_updated: "2026-03-02T00:22:03.074Z"
progress:
  total_phases: 2
  completed_phases: 2
  total_plans: 7
  completed_plans: 7
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-01)

**Core value:** A framework that enforces clean architecture by default — ECS-only game logic, event-bus-only communication, isolated plugins — so games stay maintainable as they grow.
**Current focus:** Phase 2 — Plugin Infrastructure

## Current Position

Phase: 2 of 7 (Plugin Infrastructure)
Plan: 3 of 4 in current phase
Status: In progress
Last activity: 2026-03-02 — Completed 02-03 (parse_declared_deps, detect_undeclared_service_deps, Check 6 in run())

Progress: [█████░░░░░] ~43%

## Performance Metrics

**Velocity:**
- Total plans completed: 6
- Average duration: ~3 min/plan
- Total execution time: ~11 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-core-infrastructure | 4 | ~11 min | ~2.75 min |
| 02-plugin-infrastructure | 3 | ~13 min | ~4.3 min |

**Recent Trend:**
- Last 5 plans: 01-04, 02-01, 02-02, 02-03
- Trend: On track — Phase 2 plan 3 complete

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

### Pending Todos

None yet.

### Blockers/Concerns

- [Research flag] Phase 1: Deferred bus re-entrancy guard edge cases with evolved.lua query iteration — worth a spike before committing to the design
- [Research flag] Phase 6 (if transport is demonstrated): Fragment ID thread divergence in love.thread entry points needs validation during implementation

## Session Continuity

Last session: 2026-03-02
Stopped at: Completed 02-03-PLAN.md — undeclared service dep detection (parse_declared_deps, detect_undeclared_service_deps, Check 6 in Validator.run())
Resume file: None
