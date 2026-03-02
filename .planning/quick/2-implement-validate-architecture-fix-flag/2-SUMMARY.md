---
plan: 2
title: "Implement validate_architecture --fix for missing test files"
phase: quick
subsystem: devops
tags: [validator, tooling, testing]
dependency_graph:
  requires: []
  provides: [validate_architecture --fix flag]
  affects: [scripts/validate_architecture.lua, tests/validate_architecture_spec.lua]
tech_stack:
  added: []
  patterns: [stub generation, directory creation via os.execute]
key_files:
  created: []
  modified:
    - scripts/validate_architecture.lua
    - tests/validate_architecture_spec.lua
decisions:
  - create_stub_spec is a local function (not Validator method) — only used internally by Validator.run
  - Re-detect missing tests after fix to get accurate post-fix error count
  - Tests use real src/plugins/testfix/init.lua fixture so find_lua_files("src") picks it up naturally
metrics:
  duration: ~5 min
  completed: "2026-03-02"
  tasks_completed: 2
  files_modified: 2
---

# Quick Task 2: Implement validate_architecture --fix for missing test files

**One-liner:** Validator --fix creates pending stub spec files for every src/ file missing a tests/ mirror, then re-scans to report accurate post-fix counts.

## What Was Built

The `--fix` flag in `scripts/validate_architecture.lua` now creates stub test spec files for any `src/` Lua file that lacks a corresponding `tests/` `_spec.lua` mirror.

### Implementation

**`scripts/validate_architecture.lua`:**

1. Removed the "not yet implemented" note from `Validator.run()`.
2. Added `create_stub_spec(spec_path, module_name)` local helper that:
   - Creates parent directories via `os.execute('mkdir -p ...')`
   - Writes a minimal busted spec with `describe(module_name)` / `pending("TODO: add tests")` structure
   - Returns `true` on success, `false` on IO failure
3. In `Validator.run()`, after `detect_missing_tests()`, when `opts.fix` is true:
   - Iterates missing tests, extracts module name from file basename
   - Calls `create_stub_spec()` for each
   - Prints "Fixed: created N missing test file(s)"
   - Re-runs `detect_missing_tests()` to get accurate remaining count

### Stub Format

```lua
describe("module_name", function()
	pending("TODO: add tests")
end)
```

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Implement --fix in validate_architecture.lua | 3dd5034 |
| 2 | Add tests for --fix behavior | 22d9f12 |

## Test Coverage

Two new tests in `tests/validate_architecture_spec.lua` under `describe("Validator.run with --fix")`:

1. **Creates stub spec for src file with no matching test** — creates a real `src/plugins/testfix/init.lua`, runs with `fix=true`, verifies stub created with correct `describe`/`pending` content.
2. **Reduces error count to zero after fixing all missing tests** — verifies `detect_missing_tests` returns 0 violations after `--fix` creates the stub.

Both tests use `before_each`/`after_each` hooks to clean up `src/plugins/testfix/` and `tests/plugins/testfix/`.

Full CI: 289 successes / 0 failures / 0 errors.

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `scripts/validate_architecture.lua` — FOUND (modified)
- `tests/validate_architecture_spec.lua` — FOUND (modified)
- Commit 3dd5034 — verified
- Commit 22d9f12 — verified
- `busted tests/validate_architecture_spec.lua` — 38 successes, 0 failures
- `scripts/full-check.sh` — All checks passed
