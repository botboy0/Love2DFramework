---
phase: 01-devops-foundation
plan: 02
subsystem: infra
tags: [pre-commit, selene, stylua, busted, testing, hooks, ci]

# Dependency graph
requires:
  - 01-01 (selene.toml, love2d.yml, .stylua.toml, project structure)
provides:
  - Pre-commit hook enforcing selene lint + stylua auto-format on all staged Lua files
  - busted 2.3.0 test framework with _spec.lua pattern discovery
  - Plugin test harness (stub world/bus/registry isolation context)
  - Full-suite local check script (lint + format + tests + validator)
  - tests/selene.toml + busted.yml + tests/love2d_test.yml for test file linting
affects: [all subsequent phases, Phase 2 plugin tests]

# Tech tracking
tech-stack:
  added: [busted 2.3.0 (via luarocks --local)]
  patterns:
    - Pre-commit auto-formats with stylua then hard-blocks on selene errors
    - Test files linted with separate selene config (tests/selene.toml) using love2d_test std
    - Plugin tests use isolated stub context (world/bus/registry) — real ECS wired in Phase 2

key-files:
  created:
    - .githooks/pre-commit
    - .busted
    - busted.yml
    - tests/selene.toml
    - tests/love2d_test.yml
    - tests/helpers/plugin_harness.lua
    - tests/main_spec.lua
    - scripts/full-check.sh
  modified:
    - .githooks/pre-commit (deviation fix: split src vs test selene config)

key-decisions:
  - "Test files require separate selene config (tests/selene.toml) — lua51 base defines assert as function, busted assert.is_true/is_table etc. require any:true override not achievable via + combinator"
  - "Pre-commit hook splits staged files by directory: tests/ use tests/selene.toml, src/root use root selene.toml"
  - "busted installed locally via luarocks --local to ~/.luarocks (system-wide install requires root)"

requirements-completed: [DEV-03, DEV-05]

# Metrics
duration: 10min
completed: 2026-03-01
---

# Phase 1 Plan 02: Pre-commit Hooks and Test Framework Summary

**Pre-commit hook (stylua auto-format + selene lint hard-block) and busted test framework with stub plugin isolation harness; test files use separate selene std to allow busted assert globals**

## Performance

- **Duration:** 10 min
- **Started:** 2026-03-01T12:55:15Z
- **Completed:** 2026-03-01T13:05:00Z
- **Tasks:** 3
- **Files modified:** 8 created, 1 modified

## Accomplishments

- Created `.githooks/pre-commit` — stylua auto-formats and re-stages, then selene lint hard-blocks the commit on errors. lib/ vendored code excluded. git configured with `core.hooksPath .githooks`.
- Verified pre-commit end-to-end: bad formatting auto-fixed and committed; undeclared global correctly rejected with selene error output.
- Installed busted 2.3.0 via `luarocks install busted --local` (installed to ~/.luarocks/bin/busted).
- Created `.busted` config with `_spec` pattern, `tests/` root, `utfTerminal` verbose output.
- Created `tests/helpers/plugin_harness.lua` — stub world/bus/registry isolation context matching CONTEXT.md spec; teardown clears all state.
- Created `tests/main_spec.lua` — 3 smoke tests (framework operational, context creation, teardown) all pass.
- Created `busted.yml` selene std and `tests/love2d_test.yml` combined std (love2d + busted globals with `assert: any: true`).
- Created `tests/selene.toml` using `love2d_test` std for test file linting — test files now cleanly pass selene.
- Created `scripts/full-check.sh` — 4-step pipeline: selene lint, stylua format check, busted tests, architecture validator (graceful skip if not present).

## Task Commits

Each task was committed atomically:

1. **Task 1: Create pre-commit hook** - `c703b17` (feat)
2. **Task 2: Set up busted test framework with plugin isolation harness** - `9ced03d` (feat)
3. **Task 2 deviation fix: Update pre-commit hook for test file selene config** - `178b6d1` (fix)
4. **Task 3: Create local full-suite check script** - `8668f28` (feat)

## Files Created/Modified

- `.githooks/pre-commit` - Pre-commit hook: stylua auto-format + git add + selene lint (split src/test configs)
- `.busted` - Busted test framework config (_spec pattern, tests/ root, utfTerminal)
- `busted.yml` - Selene std definition for busted globals (describe, it, assert, spy, stub, mock, etc.)
- `tests/love2d_test.yml` - Combined selene std: love2d globals + busted globals with `assert: any: true`
- `tests/selene.toml` - Selene config for test files using love2d_test std
- `tests/helpers/plugin_harness.lua` - Stub test harness: isolated world/bus/registry context + teardown
- `tests/main_spec.lua` - Smoke tests: framework operational (3 tests, all pass)
- `scripts/full-check.sh` - Local full-suite runner: lint + format check + tests + validator

## Decisions Made

- Used separate `tests/selene.toml` with `tests/love2d_test.yml` combined std instead of `+` combinator — the `+` combinator inherits lua51's `assert` function definition which overrides busted's `assert: any: true`, causing false errors on `assert.is_true`, `assert.is_table`, etc.
- Pre-commit hook detects test vs src files by `grep '^tests/'` and passes appropriate `--config` — ensures both test and source files are correctly linted at commit time.
- busted installed locally (`--local`) — system luarocks requires root; `~/.luarocks/bin` must be in PATH.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Added busted selene std definitions for test file linting**
- **Found during:** Task 2 (running selene on test files to verify pre-commit compatibility)
- **Issue:** Test files use busted globals (`describe`, `it`) and busted assert extensions (`assert.is_true`, `assert.is_table`, `assert.are.equal`) — not in love2d std. Pre-commit hook would reject test file commits.
- **Fix:** Created `busted.yml` (busted globals std), `tests/love2d_test.yml` (combined love2d + busted with `assert: any: true`), `tests/selene.toml` (uses love2d_test std). Updated pre-commit hook to route test files to `tests/selene.toml`.
- **Files modified:** `busted.yml` (new), `tests/love2d_test.yml` (new), `tests/selene.toml` (new), `.githooks/pre-commit` (modified)
- **Commit:** `178b6d1`

**2. [Rule 3 - Blocking Issue] Discovered lua51+busted std combinator doesn't override assert**
- **Found during:** Task 2 (attempting to use `std = "love2d+busted"`)
- **Issue:** selene's `+` combinator for std definitions inherits the lua51 base `assert` function definition, which does not allow field access. busted's `assert: any: true` in busted.yml doesn't override it when combined.
- **Fix:** Created `tests/love2d_test.yml` as a single combined std without base inheritance conflicts — explicitly lists all love2d and busted globals with `assert: any: true`.
- **Files modified:** `tests/love2d_test.yml` (new)
- **Committed in:** `9ced03d`

---

**Total deviations:** 2 auto-fixed (Rule 2 and Rule 3)
**Impact on plan:** Essential fixes — without them, the pre-commit hook would reject all test file commits. No scope creep.

## Verification Results

All success criteria verified:

1. `git config core.hooksPath` outputs `.githooks`
2. `.githooks/pre-commit` is executable, contains `selene` (7 occurrences) and `stylua` (3 occurrences)
3. Staged file with undeclared global rejected by selene with `error[unscoped_variables]`
4. Staged file with bad formatting auto-formatted by stylua and committed successfully
5. `busted` runs: 21 successes / 0 failures / 0 errors
6. `bash scripts/full-check.sh` completes with all 4 steps passing

## Next Phase Readiness

- Pre-commit enforcement active — no non-conforming Lua code can enter the repo
- busted test framework ready for Phase 2 plugin unit tests
- Plugin harness stubs (world/bus/registry) ready to be replaced with real evolved.lua ECS in Phase 2
- Full-suite script provides one-command quality gate for local development

---
*Phase: 01-devops-foundation*
*Completed: 2026-03-01*

## Self-Check: PASSED

All artifacts verified:
- .githooks/pre-commit: FOUND
- .busted: FOUND
- busted.yml: FOUND
- tests/helpers/plugin_harness.lua: FOUND
- tests/main_spec.lua: FOUND
- scripts/full-check.sh: FOUND
- 01-02-SUMMARY.md: FOUND

All commits verified:
- c703b17 (Task 1: pre-commit hook): FOUND
- 9ced03d (Task 2: busted framework + harness): FOUND
- 178b6d1 (Deviation fix: pre-commit hook split config): FOUND
- 8668f28 (Task 3: full-check.sh): FOUND
