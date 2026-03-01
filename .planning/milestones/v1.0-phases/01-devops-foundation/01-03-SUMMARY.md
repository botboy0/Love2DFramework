---
phase: 01-devops-foundation
plan: 03
subsystem: infra
tags: [architecture, validation, claude-md, selene, busted, lua]

# Dependency graph
requires:
  - 01-01 (selene/stylua toolchain)
provides:
  - CLAUDE.md with architectural enforcement rules (ECS, event bus, plugin isolation)
  - scripts/validate_architecture.lua — CI architecture validator
  - tests/validate_architecture_spec.lua — 18 tests covering all detection functions
  - love2d_busted.yml — combined selene std for test files
  - examples/canonical_plugin.lua — reference plugin template
affects: [all subsequent phases, CI pipeline, pre-commit hook]

# Tech tracking
tech-stack:
  added: [busted 2.3.0 (test framework), love2d_busted selene std (test linting)]
  patterns:
    - Validator structured as module+script (testable via require, runnable via lua)
    - Per-directory selene.toml for tests/ with busted-aware std definition
    - Conservative violation heuristics to avoid false positives eroding tool trust

key-files:
  created:
    - CLAUDE.md
    - examples/canonical_plugin.lua
    - scripts/validate_architecture.lua
    - tests/validate_architecture_spec.lua
    - love2d_busted.yml
  modified:
    - tests/selene.toml (updated std from love2d_test to love2d_busted)
    - busted.yml (pre-existing, verified unchanged)

key-decisions:
  - "Validator structured as module+script using arg[0] detection — required for testability without coupling tests to script execution"
  - "love2d_busted.yml combined std with assert: any: true — overrides lua51 base assert to allow busted assert.* API methods"
  - "Conservative heuristics for global detection and logic-outside-ECS — false positives erode trust more than false negatives"
  - "Test mirroring enforced by validator (src/ -> tests/ _spec.lua) — structural enforcement not just convention"

patterns-established:
  - "Architecture validator is the CI enforcement layer for rules selene cannot check"
  - "Test files use tests/selene.toml with love2d_busted std (not root selene.toml)"
  - "Canonical plugin template lives in examples/ — CLAUDE.md references it, never inlines"

requirements-completed: [DEV-06, DEV-07]

# Metrics
duration: 6min
completed: 2026-03-01
---

# Phase 1 Plan 03: CLAUDE.md and Architecture Validator Summary

**CLAUDE.md documents ECS-only logic, event-bus-only communication, and plugin isolation rules; architecture validator detects globals, cross-plugin imports, and missing test mirrors with 18 passing busted tests**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-01T12:54:49Z
- **Completed:** 2026-03-01T13:00:34Z
- **Tasks:** 3
- **Files modified:** 6 created, 1 modified

## Accomplishments

- Created `CLAUDE.md` at project root with 5 architectural rules (ECS-only logic, event-bus communication, plugin:init(ctx) registration, plugin isolation, no global state), each with do/don't code examples. References `examples/canonical_plugin.lua` — does not inline the template.
- Created `examples/canonical_plugin.lua` placeholder implementing the standard plugin interface, ready for Phase 2 completion.
- Created `scripts/validate_architecture.lua` — architecture validator runnable as `lua scripts/validate_architecture.lua`. Detects: undeclared globals in src/, cross-plugin imports, direct ECS world access in love callbacks, missing test file mirrors. Exits 0/1. Passes selene and stylua.
- Created `tests/validate_architecture_spec.lua` — 18 busted tests covering all four detection functions: 7 for `detect_globals`, 5 for `detect_cross_plugin_imports`, 4 for `detect_missing_tests`, 2 integration tests for `Validator.run`. All pass.
- Created `love2d_busted.yml` combined selene std definition that adds busted globals (`describe`, `it`, `assert` with `any: true` to allow busted's extended assert API) on top of the Love2D whitelist.
- Updated `tests/selene.toml` to use `love2d_busted` std so test files pass selene without false positives.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create CLAUDE.md with architectural enforcement rules** - `e20ee82` (feat)
2. **Task 2: Create architecture validator script** - `a2ee521` (feat)
3. **Task 3: Create tests for the architecture validator** - `ee64dfd` (feat)

## Files Created/Modified

- `CLAUDE.md` — Architectural enforcement rules: ECS-only logic, event bus communication, plugin isolation, naming conventions, file organization, testing rules
- `examples/canonical_plugin.lua` — Plugin template placeholder (Phase 2 implementation target)
- `scripts/validate_architecture.lua` — Architecture validator: 4 detection functions + script entry point
- `tests/validate_architecture_spec.lua` — 18 busted tests for validator
- `love2d_busted.yml` — Combined Love2D + busted selene std for test files
- `tests/selene.toml` — Updated to use `love2d_busted` std (was `love2d_test` — missing file)

## Decisions Made

- Structured validator as module+script using `arg[0]` detection pattern — allows `require("scripts.validate_architecture")` in tests while still being runnable standalone with `lua scripts/validate_architecture.lua`
- Used `assert: any: true` in `love2d_busted.yml` to override lua51 base definition of `assert` — this allows busted's extended assert methods (`assert.equals`, `assert.is_true`, etc.) without selene flagging them as incorrect stdlib use
- Conservative heuristics throughout: the validator only flags clear violations. Global detection uses a conservative line-start pattern; cross-plugin detection requires the path to be under `src/plugins/`; logic-outside-ECS only checks love callbacks and skips system files

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing] Created love2d_busted.yml and updated tests/selene.toml**
- **Found during:** Task 3 (running selene on test spec)
- **Issue:** `selene tests/validate_architecture_spec.lua` reported 49 errors — selene didn't know about busted globals (`describe`, `it`, `assert.equals`, etc.). `tests/selene.toml` referenced `love2d_test` std that didn't exist.
- **Fix:** Created `love2d_busted.yml` combining Love2D and busted globals with `assert: any: true` to allow busted's extended assert API. Updated `tests/selene.toml` to use the correct std name `love2d_busted`.
- **Files modified:** love2d_busted.yml (created), tests/selene.toml (updated std reference)
- **Commit:** ee64dfd (Task 3 commit)

**2. [Rule 1 - Bug] Fixed stylua formatting on validate_architecture.lua**
- **Found during:** Task 2 verification (stylua --check)
- **Issue:** stylua required reformatting 3 code blocks: single-quoted string to double-quoted, long `elseif` chain to multi-line, and long string concatenation to multi-line
- **Fix:** Applied `stylua scripts/validate_architecture.lua` auto-format
- **Files modified:** scripts/validate_architecture.lua
- **Committed in:** a2ee521 (Task 2 commit, pre-commit hook applied stylua)

## Issues Encountered

- None beyond the two auto-fixed deviations above.

## Next Phase Readiness

- CLAUDE.md is the authoritative reference for all architectural rules — Claude and human contributors follow it
- Architecture validator is ready to be wired into CI (Phase 1 Plan 02 already set up GitHub Actions)
- busted test framework installed and configured; test harness available in tests/helpers/
- DEV-06 and DEV-07 requirements satisfied

---
*Phase: 01-devops-foundation*
*Completed: 2026-03-01*
