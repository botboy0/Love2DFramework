# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-01)

**Core value:** A framework that enforces clean architecture by default — ECS-only game logic, event-bus-only communication, isolated plugins — so games stay maintainable as they grow.
**Current focus:** Phase 1 — Core Infrastructure

## Current Position

Phase: 1 of 7 (Core Infrastructure)
Plan: 2 of ? in current phase
Status: In progress
Last activity: 2026-03-01 — Completed 01-02 (Bus error_mode + NullTransport)

Progress: [██░░░░░░░░] ~14%

## Performance Metrics

**Velocity:**
- Total plans completed: 2
- Average duration: ~2 min/plan
- Total execution time: ~4 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-core-infrastructure | 2 | ~4 min | ~2 min |

**Recent Trend:**
- Last 5 plans: 01-01, 01-02
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

### Pending Todos

None yet.

### Blockers/Concerns

- [Research flag] Phase 1: Deferred bus re-entrancy guard edge cases with evolved.lua query iteration — worth a spike before committing to the design
- [Research flag] Phase 6 (if transport is demonstrated): Fragment ID thread divergence in love.thread entry points needs validation during implementation

## Session Continuity

Last session: 2026-03-01
Stopped at: Completed 01-01-PLAN.md — Worlds single-world mode + empty components; both 01-01 and 01-02 are now complete, ready for 01-03
Resume file: None
