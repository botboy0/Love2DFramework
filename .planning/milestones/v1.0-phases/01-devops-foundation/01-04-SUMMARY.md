---
phase: 01-devops-foundation
plan: "04"
subsystem: ci-pipeline
tags: [github-actions, ci, devops, branch-protection]
dependency_graph:
  requires: [01-02, 01-03]
  provides: [ci-pipeline, branch-protection-docs]
  affects: [all-future-code-changes]
tech_stack:
  added: [github-actions, selene-0.27.1, stylua-0.20.0]
  patterns: [ci-as-enforcement-layer, mirror-local-ci]
key_files:
  created:
    - .github/workflows/ci.yml
  modified:
    - scripts/full-check.sh
    - CLAUDE.md
decisions:
  - Sequential single-job CI (lint->format->test->validate) matches local full-check script order
  - Pinned tool versions (selene 0.27.1, stylua 0.20.0) for reproducible CI
  - Job name "Lint, Format, Test, Validate" chosen as the branch protection status check identifier
  - Branch protection must be configured manually — no GitHub API automation
metrics:
  duration: "4 min"
  completed: "2026-03-01"
  tasks_completed: 2
  files_created: 1
  files_modified: 2
---

# Phase 01 Plan 04: GitHub Actions CI Pipeline Summary

GitHub Actions CI pipeline enforcing lint + format check + tests + architecture validation on every push and PR to main, with full-check script synced to CI and branch protection setup documented.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create GitHub Actions CI workflow | 856a3e1 | .github/workflows/ci.yml |
| 2 | Sync full-check script and document branch protection | 6346154 | scripts/full-check.sh, CLAUDE.md |

## What Was Built

### `.github/workflows/ci.yml`

Single-job CI pipeline that:
- Triggers on push to `main` and pull requests targeting `main`
- Installs Lua 5.1 via `leafo/gh-actions-lua@v10`
- Installs LuaRocks via `leafo/gh-actions-luarocks@v4`
- Installs busted via LuaRocks
- Downloads pinned selene 0.27.1 binary from GitHub releases
- Downloads pinned stylua 0.20.0 binary from GitHub releases
- Runs `selene src/ main.lua conf.lua`
- Runs `stylua --check src/ main.lua conf.lua`
- Runs `busted`
- Runs `lua scripts/validate_architecture.lua`

Job is named `Lint, Format, Test, Validate` — this exact string must be used as the required status check in GitHub branch protection settings.

### `scripts/full-check.sh` Updates

- Added sync comment at top: "Mirrors .github/workflows/ci.yml — keep in sync."
- Removed the conditional `if [ -f "scripts/validate_architecture.lua" ]` guard — the validator now always exists (created in Plan 03)
- All 4 steps now run unconditionally, mirroring CI exactly

### `CLAUDE.md` CI & Branch Protection Section

New section documenting:
- CI pipeline structure and what each step enforces
- How to run the local check script before pushing
- Step-by-step manual GitHub branch protection setup instructions
- Required status check name for branch protection: `Lint, Format, Test, Validate`

## Decisions Made

1. **Sequential single-job CI** — All checks in one job, no parallelism. Failure in step 1 (lint) skips remaining steps and fails fast. Matches the local `full-check.sh` execution model.

2. **Pinned tool versions** — `selene 0.27.1` and `stylua 0.20.0` are hardcoded in the workflow. These match the versions used during development. Unpinned versions can cause spurious CI failures when tools release breaking changes.

3. **Job name as status check identifier** — The job name `Lint, Format, Test, Validate` doubles as the branch protection status check name. GitHub uses job names for this. Using a descriptive name makes the protection rule self-documenting.

4. **No branch protection automation** — GitHub's branch protection API requires repository admin auth. Documenting the manual steps in CLAUDE.md is the correct approach for a local-dev setup.

## Deviations from Plan

None — plan executed exactly as written.

The `full-check.sh` script from Plan 02 already had all 4 steps in the correct order. The deviation was the removal of the conditional validator guard (which was a placeholder that Plan 02 added anticipating Plan 03 might not exist yet). This is a minor cleanup, not a meaningful deviation.

## Self-Check

- [x] `.github/workflows/ci.yml` created and YAML-valid
- [x] CI triggers: push and pull_request on main
- [x] CI steps: selene, stylua, busted, lua validate_architecture
- [x] `scripts/full-check.sh` has sync comment and runs all 4 steps unconditionally
- [x] `CLAUDE.md` has CI & Branch Protection section
- [x] Task 1 commit: 856a3e1
- [x] Task 2 commit: 6346154
