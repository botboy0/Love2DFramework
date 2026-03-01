# Roadmap: FactoryGame

## Overview

v1 delivers the enforcement foundation that prevents the code quality degradation that killed the previous attempt. Phase 1 locks in the devops stack (linting, formatting, testing, CI, architectural rules). Phase 2 builds the core infrastructure (event bus, plugin registry, ECS worlds, transport layer) that all game features will plug into. No game code ships in v1 — the goal is a codebase that enforces its own architecture before the first game system is written.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: DevOps Foundation** - Linting, formatting, testing, CI, and architectural enforcement rules in place before any game code (completed 2026-03-01)
- [ ] **Phase 2: Core Infrastructure** - Event bus, plugin registry, ECS worlds, transport layer, and canonical plugin example

## Phase Details

### Phase 1: DevOps Foundation
**Goal**: The project enforces its own architectural rules — no conforming commit can introduce ECS violations, global state, or cross-plugin coupling
**Depends on**: Nothing (first phase)
**Requirements**: DEV-01, DEV-02, DEV-03, DEV-04, DEV-05, DEV-06, DEV-07
**Success Criteria** (what must be TRUE):
  1. A commit introducing an undeclared global is rejected by the pre-commit hook before it reaches the repo
  2. A commit with un-formatted Lua is rejected by the pre-commit hook
  3. CI runs lint → test → build on every push and hard-blocks merge on any failure
  4. CLAUDE.md exists and documents the architectural rules Claude must follow when generating code
  5. The architecture validator script detects and reports globals, cross-plugin imports, and client-side game logic
**Plans:** 4/4 plans complete
- [x] 01-01-PLAN.md — Project scaffolding + selene linting + stylua formatting
- [x] 01-02-PLAN.md — Pre-commit hooks + busted test framework
- [ ] 01-03-PLAN.md — CLAUDE.md architectural rules + architecture validator
- [ ] 01-04-PLAN.md — GitHub Actions CI pipeline

### Phase 2: Core Infrastructure
**Goal**: The shared runtime exists — event bus, plugin registry, dual ECS worlds, and solo transport are working and tested, with a canonical plugin example as the reference for all future game plugins
**Depends on**: Phase 1
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05, INFRA-06, INFRA-07
**Success Criteria** (what must be TRUE):
  1. A plugin registered via `plugin:init(ctx)` can emit and receive events through the bus without directly calling another plugin
  2. The event bus defers dispatch — handlers cannot emit new events synchronously (re-entrancy guard blocks it)
  3. A plugin loaded in isolation (without sibling plugins) passes all its tests using the isolation test template
  4. The canonical plugin example demonstrates component registration, system registration, and event handling in one file that passes lint and tests
  5. A message sent through love.thread channel transport arrives on the other side in the same tick it was flushed
**Plans:** 4 plans
- [ ] 02-01-PLAN.md — Vendor libraries (evolved.lua, binser) + deferred-dispatch event bus (TDD)
- [ ] 02-02-PLAN.md — Shared components, dual ECS worlds, context object pattern (TDD)
- [ ] 02-03-PLAN.md — Plugin registry with dependency sort + transport layer (TDD)
- [ ] 02-04-PLAN.md — Plugin isolation harness upgrade, canonical plugin, main.lua wiring

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. DevOps Foundation | 4/4 | Complete   | 2026-03-01 |
| 2. Core Infrastructure | 0/4 | Not started | - |
