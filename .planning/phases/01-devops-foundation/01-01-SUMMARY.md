---
phase: 01-devops-foundation
plan: 01
subsystem: infra
tags: [selene, stylua, lua, love2d, linting, formatting]

# Dependency graph
requires: []
provides:
  - Project directory layout (src/core, src/plugins, src/client, src/server, lib, tests, assets, examples)
  - selene linting configured with unscoped_variables=deny and custom Love2D std definition
  - stylua formatting configured with tabs, 120 column width
  - Minimal conf.lua and main.lua Love2D entry points
affects: [02-devops-foundation, all subsequent phases]

# Tech tracking
tech-stack:
  added: [selene 0.30.0, stylua 2.3.1]
  patterns: [unscoped_variables=deny enforces no accidental globals, _prefix convention for intentionally unused parameters]

key-files:
  created:
    - selene.toml
    - love2d.yml
    - .stylua.toml
    - .styluaignore
    - conf.lua
    - main.lua
    - src/core/.gitkeep
    - src/plugins/.gitkeep
    - src/client/.gitkeep
    - src/server/.gitkeep
    - lib/.gitkeep
    - tests/.gitkeep
    - tests/helpers/.gitkeep
    - assets/.gitkeep
    - examples/.gitkeep
  modified: []

key-decisions:
  - "Use unscoped_variables=deny (not global_usage=deny) — correct selene rule name for catching undeclared globals"
  - "Use _dt convention for intentionally unused Love2D update parameter to pass selene unused_variable check"
  - "lib/ excluded from stylua via .styluaignore for vendored code"

patterns-established:
  - "Unused parameters prefixed with _ to satisfy selene unused_variable rule"
  - "All Lua files formatted with stylua before committing"
  - "selene catches undeclared globals as errors (exit code 1)"

requirements-completed: [DEV-01, DEV-02]

# Metrics
duration: 2min
completed: 2026-03-01
---

# Phase 1 Plan 01: Project Scaffold and Static Analysis Summary

**selene linting (unscoped_variables=deny) + stylua formatting scaffolded with custom love2d.yml std whitelisting love/world/eventBus/registry globals**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-01T12:49:36Z
- **Completed:** 2026-03-01T12:52:06Z
- **Tasks:** 3
- **Files modified:** 15

## Accomplishments

- Created full project directory structure matching CONTEXT.md layout (src/core, src/plugins, src/client, src/server, lib, tests, tests/helpers, assets, examples)
- Configured selene with unscoped_variables=deny and custom love2d.yml std whitelisting love, world, eventBus, registry globals — undeclared globals are hard errors
- Configured stylua with tabs, 120-column width, and .styluaignore excluding lib/ vendored code
- Created minimal conf.lua and main.lua Love2D entry points, linted and formatted

## Task Commits

Each task was committed atomically:

1. **Task 1: Create project directory structure and Love2D entry points** - `6271920` (feat)
2. **Task 2: Configure selene linting with custom Love2D std definition** - `99281f6` (feat)
3. **Task 3: Configure stylua formatting** - `bb974d5` (feat)

## Files Created/Modified

- `selene.toml` - Selene linting config with unscoped_variables=deny, std=love2d
- `love2d.yml` - Custom selene std definition whitelisting love, world, eventBus, registry
- `.stylua.toml` - Stylua formatting config (tabs, 120 columns, AutoPreferDouble quotes)
- `.styluaignore` - Excludes lib/ from stylua formatting
- `conf.lua` - Love2D configuration entry point (identity, version, window dimensions)
- `main.lua` - Love2D main entry point with love.load, love.update(_dt), love.draw stubs
- `src/core/.gitkeep`, `src/plugins/.gitkeep`, `src/client/.gitkeep`, `src/server/.gitkeep` - Source subdirs
- `lib/.gitkeep`, `tests/.gitkeep`, `tests/helpers/.gitkeep`, `assets/.gitkeep`, `examples/.gitkeep` - Root dirs

## Decisions Made

- Used `unscoped_variables` rule name (not `global_usage`) — the plan spec had the wrong rule name; the actual selene rule for catching undeclared globals is `unscoped_variables`
- Used `_dt` convention in `love.update` to suppress the unused_variable warning on the conventional Love2D parameter
- Excluded `lib/` from stylua via `.styluaignore` as specified for vendored libraries

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected selene rule name from global_usage to unscoped_variables**
- **Found during:** Task 2 (Configure selene linting)
- **Issue:** Plan specified `global_usage = "deny"` but selene 0.30.0 has no such rule — the correct rule name is `unscoped_variables`
- **Fix:** Updated selene.toml to use `unscoped_variables = "deny"` which correctly flags undeclared globals as errors
- **Files modified:** selene.toml
- **Verification:** `selene main.lua conf.lua` exits 0; `selene /tmp/test_global.lua` exits 1 with `error[unscoped_variables]`
- **Committed in:** 99281f6 (Task 2 commit)

**2. [Rule 1 - Bug] Fixed unused dt parameter in love.update to use _dt convention**
- **Found during:** Task 2 (running selene verification)
- **Issue:** `selene main.lua` reported `warning[unused_variable]: dt is defined, but never used` — violating the zero-warnings requirement
- **Fix:** Changed `function love.update(dt)` to `function love.update(_dt)` — Lua convention for intentionally unused parameters
- **Files modified:** main.lua
- **Verification:** `selene main.lua conf.lua` reports 0 warnings
- **Committed in:** 99281f6 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - Bug)
**Impact on plan:** Both fixes necessary for correctness — wrong rule name would not enforce intended constraint, unused parameter would fail zero-warning requirement. No scope creep.

## Issues Encountered

- selene and stylua binaries not available on the system — installed via pre-built GitHub release binaries to `~/.local/bin/`

## User Setup Required

The following tools were installed to `~/.local/bin/` during plan execution. Ensure this is in your PATH:

- `selene 0.30.0` — downloaded from GitHub releases
- `stylua 2.3.1` — downloaded from GitHub releases

Add to shell profile if not already present:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Next Phase Readiness

- Directory structure complete and ready for source files
- selene catches undeclared globals as hard errors — architectural constraint enforced from day one
- stylua formatting consistent — no manual formatting required
- Ready for Phase 1 Plan 02 (pre-commit hooks and CI configuration)

---
*Phase: 01-devops-foundation*
*Completed: 2026-03-01*
