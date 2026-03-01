# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-01)

**Core value:** A framework that enforces clean architecture by default — ECS-only game logic, event-bus-only communication, isolated plugins — so games stay maintainable as they grow.
**Current focus:** Phase 1 — Core Infrastructure

## Current Position

Phase: 1 of 7 (Core Infrastructure)
Plan: 3 of ? in current phase
Status: In progress
Last activity: 2026-03-02 — Completed 01-03 (Context transport wiring + Registry error_mode + side enforcement)

Progress: [███░░░░░░░] ~21%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: ~3 min/plan
- Total execution time: ~8 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-core-infrastructure | 3 | ~8 min | ~2.7 min |

**Recent Trend:**
- Last 5 plans: 01-01, 01-02, 01-03
- Trend: On track

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

### Pending Todos

None yet.

### Blockers/Concerns

- [Research flag] Phase 1: Deferred bus re-entrancy guard edge cases with evolved.lua query iteration — worth a spike before committing to the design
- [Research flag] Phase 6 (if transport is demonstrated): Fragment ID thread divergence in love.thread entry points needs validation during implementation

## Session Continuity

Last session: 2026-03-02
Stopped at: Completed 01-03-PLAN.md — Context transport wiring, auto-bridge, Registry error_mode and side enforcement; ready for 01-04
Resume file: None
