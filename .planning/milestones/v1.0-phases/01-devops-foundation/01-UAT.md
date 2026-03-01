---
status: complete
phase: 01-devops-foundation
source: [01-01-SUMMARY.md, 01-02-SUMMARY.md, 01-03-SUMMARY.md, 01-04-SUMMARY.md]
started: 2026-03-01T15:00:00Z
updated: 2026-03-01T15:30:00Z
---

## Current Test

[testing complete]

## Tests

### 1. selene catches undeclared globals
expected: Run `selene src/ main.lua conf.lua` — exits 0. A file with an undeclared global triggers `error[unscoped_variables]` and exits non-zero.
result: pass

### 2. stylua enforces formatting
expected: Run `stylua --check src/ main.lua conf.lua` — exits 0 (all files already formatted).
result: pass

### 3. Pre-commit hook blocks undeclared globals
expected: Create a temp .lua file with an undeclared global, `git add` it, and `git commit` — the commit is rejected with selene error output.
result: pass

### 4. Pre-commit hook auto-formats staged files
expected: Create a .lua file with bad formatting (e.g., wrong indentation), `git add` and `git commit` — stylua auto-formats it and the commit succeeds (assuming no selene errors).
result: pass

### 5. busted runs all tests
expected: Run `busted` — all tests pass with 0 failures and 0 errors. Output shows test descriptions.
result: pass

### 6. Architecture validator runs clean
expected: Run `lua scripts/validate_architecture.lua` — exits 0 with no violations reported.
result: pass

### 7. full-check.sh passes all steps
expected: Run `bash scripts/full-check.sh` — all 4 steps (lint, format check, tests, architecture validation) pass and script exits 0.
result: pass

### 8. CLAUDE.md documents architectural rules
expected: CLAUDE.md exists at project root and contains the 5 architectural rules: ECS-only logic, event bus communication, plugin init(ctx), plugin isolation, no global state.
result: pass

### 9. CI workflow configured
expected: `.github/workflows/ci.yml` exists, triggers on push/PR to main, and runs selene, stylua, busted, and validate_architecture in sequence.
result: pass

## Summary

total: 9
passed: 9
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
