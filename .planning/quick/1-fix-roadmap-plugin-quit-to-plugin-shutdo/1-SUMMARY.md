---
plan: 1
title: "Fix ROADMAP plugin:quit() references to plugin:shutdown()"
completed: "2026-03-02"
duration: "< 1 min"
tasks_completed: 1
tasks_total: 1
files_modified: 1
commits: ["f004fce"]
---

# Quick Task 1: Fix ROADMAP plugin:quit() to plugin:shutdown() Summary

**One-liner:** Corrected two stale `plugin:quit()` references in ROADMAP.md success criteria to match the actual `plugin:shutdown(ctx)` API in `src/core/registry.lua`.

## What Was Done

Replaced both occurrences of `plugin:quit()` with `plugin:shutdown()` in `.planning/ROADMAP.md`:

- **Line 34** (Phase 1 success criteria): "Shutting down triggers `plugin:shutdown()` on all registered plugins in reverse boot order"
- **Line 65** (Phase 3 success criteria): "The input plugin boots and shuts down via the standard `plugin:init(ctx)` / `plugin:shutdown()` lifecycle without special-casing in `main.lua`"

## Verification

`grep -c "plugin:quit()" .planning/ROADMAP.md` returned `0` — no remaining occurrences.

## Deviations from Plan

None - plan executed exactly as written.

## Commits

| Hash | Message |
|------|---------|
| f004fce | fix(roadmap): replace plugin:quit() with plugin:shutdown() to match code |
