---
plan: 1
title: "Fix ROADMAP plugin:quit() references to plugin:shutdown()"
tasks: 1
---

## Task 1: Update ROADMAP.md naming

**Files:** `.planning/ROADMAP.md`

**Action:** Replace both occurrences of `plugin:quit()` with `plugin:shutdown()` to match the actual API in `src/core/registry.lua`:
- Line 34: In Phase 1 success criteria, change "Shutting down triggers `plugin:quit()` on all registered plugins..." to use `plugin:shutdown()`
- Line 65: In Phase 3 success criteria, change "The input plugin boots and shuts down via the standard `plugin:init(ctx)` / `plugin:quit()` lifecycle..." to use `plugin:shutdown()`

The actual registry implementation calls `plugin:shutdown(ctx)` at line 281 in `src/core/registry.lua`, so documentation must match.

**Verify:** `grep -c "plugin:quit()" .planning/ROADMAP.md` returns 0

**Done:** All ROADMAP success criteria now reference the correct `plugin:shutdown()` method name, matching the actual codebase implementation.
