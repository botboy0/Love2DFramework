# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Foundation

**Shipped:** 2026-03-01
**Phases:** 2 | **Plans:** 8 | **Sessions:** ~4

### What Was Built
- Complete devops enforcement stack: selene linting, stylua formatting, pre-commit hooks, CI pipeline, architecture validator
- Core runtime infrastructure: deferred-dispatch event bus, plugin registry with topological sort, dual ECS worlds (tag-based isolation), channel transport, context object
- Plugin isolation test harness (real infrastructure, not stubs) and canonical plugin example
- 135 tests, 0 failures, main.lua wired to registry boot

### What Worked
- TDD approach (failing tests first) caught design issues early in bus, registry, and transport
- Injectable logger pattern avoided selene conflicts with global print reassignment
- Plugin harness upgrade (Phase 2) replaced Phase 1 stubs with real infrastructure — tests now exercise actual bus/world/registry
- Kahn's BFS for plugin dependency sort naturally detects cycles
- Tag-based world isolation avoids forking evolved.lua library

### What Was Inefficient
- Phase 1 plugin harness used stubs that Phase 2 immediately replaced — could have been deferred
- Architecture validator had false positives from setmetatable patterns, required brace/function depth tracking fix
- Some plan checkboxes in ROADMAP.md were not checked off during execution (cosmetic)

### Patterns Established
- `plugin:init(ctx)` with `ctx = { world, bus, config, services }` as the universal plugin API
- `Bus.new(log_fn)` injectable logger pattern for testability
- Separate selene.toml for test files (love2d_busted std) vs src files (love2d std)
- Module+script pattern (arg[0] detection) for validator: testable via require(), runnable as script
- Services.register() fail-fast on duplicate registration

### Key Lessons
1. DevOps first was the right call — every subsequent phase had lint/test/CI safety net from day one
2. Injectable dependencies (logger, channels) are essential when selene denies global mutation
3. Tag-based ECS isolation is cleaner than dual-world approaches when the ECS library is a singleton
4. Pre-commit hook routing (src vs tests selene configs) requires explicit path-based routing logic

### Cost Observations
- Model mix: primarily opus for planning, sonnet/haiku for execution agents
- Sessions: ~4 (planning, phase 1 execution, phase 2 execution, audit/completion)
- Notable: 8 plans executed in ~41 min total, ~5 min average per plan

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~4 | 2 | Established devops-first, TDD, plugin architecture |

### Cumulative Quality

| Milestone | Tests | Passing | Tech Debt Items |
|-----------|-------|---------|-----------------|
| v1.0 | 135 | 100% | 1 (INFRA-08 deferred) |

### Top Lessons (Verified Across Milestones)

1. DevOps enforcement before game code prevents architecture degradation
