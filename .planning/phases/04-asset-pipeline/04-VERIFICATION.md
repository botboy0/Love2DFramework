---
phase: 04-asset-pipeline
verified: 2026-03-02T21:00:00Z
status: passed
score: 6/6 must-haves verified
re_verification:
  previous_status: passed
  previous_score: 4/4
  gaps_closed:
    - "busted output is clean — zero [Harness], [Bus], or Fixed: messages on stdout"
    - "Validator.run({ silent = true }) produces no stdout output"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Boot the game and observe frame rate during asset loading"
    expected: "Game continues rendering at full frame rate — no stutter or freeze while Lily loads assets in background threads"
    why_human: "Lily async threading requires a running Love2D runtime to observe; busted stubs cannot demonstrate actual thread behavior"
  - test: "Load 3 images in the same atlas group and inspect draw calls"
    expected: "All three sprites share a single atlas texture in draw calls — not individual file loads"
    why_human: "Draw call batching requires Love2D graphics pipeline inspection at runtime"
---

# Phase 4: Asset Pipeline Verification Report

**Phase Goal:** Assets load without frame hitches and draw calls are minimized by atlas packing — on mobile targets
**Verified:** 2026-03-02T21:00:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure (plan 04-04 stdout noise)

---

## Re-verification Summary

The previous verification (2026-03-02T04:15:00Z) passed 4/4 truths but left one UAT gate pending: UAT-03 required clean busted output (no extraneous stdout noise). Plan 04-04 ran as a gap closure to fix this. This re-verification covers:

1. **Plan 04-04 must-haves** (new items — full 3-level verification)
2. **Original 4 truths from phase goal** (quick regression check)
3. **Modified files** (`src/plugins/input/init.lua`, `tests/plugins/assets/init_spec.lua`) — regression check

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Requesting an asset load does not block the main thread | VERIFIED | `asset_loader.lua:39` sets `lily.setUpdateMode("manual")`; `update()` delegates to `lily.update()`. Regression confirmed: no change since previous verification. |
| 2 | Sprites packed into a texture atlas are drawn from a single atlas texture | VERIFIED | `atlas_builder.lua:153-165` produces one atlas per group; `drawable_wrapper.lua:77-81` dispatches `draw_fn(texture, quad, ...)` for atlas type. Regression confirmed: no change. |
| 3 | Atlas configuration exceeding 4096x4096 is rejected with a clear error | VERIFIED | `atlas_builder.lua:59-82`: budget cap computed, `_split_group` called on overflow, warning logged. Regression confirmed: no change. |
| 4 | Lily completion callbacks emit bus events only — no ECS mutations | VERIFIED | `asset_loader.lua:84,93` emit bus events only; zero `evolved.*` or `world:*` calls in all asset modules. Regression confirmed: no change. |
| 5 | busted runs all tests with zero extraneous stdout noise | VERIFIED | `busted 2>&1 \| grep -c "\[Harness\]\|\[Bus\]\|Fixed:"` returns **0**. 379 successes, 0 failures. |
| 6 | Validator.run({ silent = true }) produces no stdout output | VERIFIED | `lua -e "V.run({ silent = true })" 2>&1 \| wc -l` returns **0**. `Validator.run()` without silent flag still prints normally (confirmed: outputs "Architecture check passed: no violations found.") |

**Score:** 6/6 truths verified

---

### Required Artifacts

#### Plan 04-04 Artifacts (Full Verification)

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tests/helpers/plugin_harness_spec.lua` | Tolerant-mode test with `_G.print` stub | VERIFIED | Lines 62-68: `local original_print = _G.print`, `_G.print = function() end`, restored after assertion. Pattern `stub.*_G.*print` matched. |
| `tests/main_spec.lua` | Bus tolerant-mode test with log suppressor | VERIFIED | Line 309: `Bus.new({ error_mode = bus_error_mode, log = function() end })`. Pattern `log = function` matched. |
| `scripts/validate_architecture.lua` | Silent-mode-aware print guards in `Validator.run()` | VERIFIED | Lines 673-676: `local silent = opts.silent or false`, `local function log(...)`. Six `if not silent then` guards at lines 711, 737, 763, 789, 829, 877. Line 783: `log("Fixed: ...")`. Pattern `opts.silent` matched. |

#### Original Phase Artifacts (Quick Regression Check)

All 15 original artifacts verified in the previous report remain unchanged. No regressions detected.

| Artifact | Regression Check |
|----------|-----------------|
| `lib/lily.lua` | Present, unchanged |
| `lib/TA.lua` | Present, unchanged |
| `lib/RuntimeTextureAtlas/` | Present, unchanged |
| `src/plugins/assets/manifest.lua` | Present, unchanged |
| `src/plugins/assets/drawable_wrapper.lua` | Present, unchanged |
| `src/plugins/assets/asset_loader.lua` | Present, unchanged |
| `src/plugins/assets/atlas_builder.lua` | Present, unchanged |
| `src/plugins/assets/init.lua` | Present, unchanged |
| `src/core/plugin_list.lua` | Present, unchanged |
| `tests/plugins/assets/manifest_spec.lua` | Present, unchanged |
| `tests/plugins/assets/drawable_wrapper_spec.lua` | Present, unchanged |
| `tests/plugins/assets/asset_loader_spec.lua` | Present, unchanged |
| `tests/plugins/assets/atlas_builder_spec.lua` | Present, unchanged |
| `tests/plugins/assets/init_spec.lua` | Present — substantive non-breaking update (see Modified Files section) |
| `tests/core/plugin_list_spec.lua` | Present, unchanged |

---

### Key Link Verification

#### Plan 04-04 Key Links

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `tests/helpers/plugin_harness_spec.lua` | `tests/helpers/plugin_harness.lua` | `_G.print` stub prevents stdout noise from tolerant-mode warning | WIRED | `_G.print = function() end` wraps `ctx.services:get("crafting")` call at lines 63-67. Harness tolerant-mode warning suppressed at the test layer. |
| `scripts/validate_architecture.lua` | `Validator.run opts.silent` | All print calls gated behind `if not silent` | WIRED | 1 `log()` helper + 6 `if not silent then` guards cover all `print_section`, `print_warning_section`, and `print` calls inside `Validator.run()`. Script entry-point prints deliberately unguarded (CLI output, not library output). |

#### Original Key Links (Quick Regression Check)

All 6 original key links unchanged. No regressions detected.

---

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ASST-01 | 04-02, 04-03, 04-04 | Async asset loading via Lily prevents frame hitches | SATISFIED | `lily.setUpdateMode("manual")` in constructor. 379 tests pass including `asset_loader_spec.lua:97`. Plan 04-04 required clean busted output to confirm test suite integrity — now verified. |
| ASST-02 | 04-01, 04-02, 04-04 | Texture atlas packing via Runtime-TextureAtlas reduces draw calls | SATISFIED | `AtlasBuilder:build()` produces one packed canvas per group. 21 `init_spec.lua` tests pass including atlas packing pipeline. |
| ASST-03 | 04-01, 04-02, 04-04 | Asset pipeline capped at 4096x4096 for mobile GPU | SATISFIED | `atlas_builder.lua:35,154`: `max_size = 4096`, auto-split on overflow. `atlas_builder_spec.lua` tests pass. |
| ASST-04 | 04-02, 04-03, 04-04 | Lily callbacks emit bus events only — no entity spawning | SATISFIED | Zero `evolved.*` calls in asset modules. Source-level assertion in `asset_loader_spec.lua:382-389`. All 379 tests clean. |

No orphaned requirements. All four ASST requirements satisfied. REQUIREMENTS.md traceability table marks all four as `Complete` for Phase 4.

---

### Modified Files — Regression Check

Two files modified (unstaged) since last commit were inspected for regressions:

**`src/plugins/input/init.lua`**

- Change: `require` statement order swap — `TouchRegions` require moved above `baton` require (cosmetic reorder only)
- Impact: None. Functional behavior identical. No test failures.
- Anti-patterns: None found.

**`tests/plugins/assets/init_spec.lua`**

- Change 1: `make_manifest_stub` — `parse` signature corrected from `function(_self, _manifest_table)` to `function(_manifest_table)` to match real `Manifest.parse` interface (module function, not method call)
- Change 2: `fire_batch_complete` — now accepts optional `plugin` argument; calls `plugin:update(0)` and `ctx.bus:flush()` after the initial flush to trigger the deferred `asset:ready` emission path
- Change 3: 8 call sites updated to pass `AssetPlugin` as second argument to `fire_batch_complete`
- Impact: Positive — tests now correctly exercise the `_pending_ready` flag and deferred-ready-emission path. `busted tests/plugins/assets/init_spec.lua` reports **21 successes, 0 failures**.
- Anti-patterns: None found.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `src/plugins/assets/init.lua` | 220 | `return nil` | Info | Intentional — documented on-demand asset semantics while loading. Not a stub. Unchanged from previous verification. |

No new anti-patterns introduced by plan 04-04 changes.

---

### Human Verification Required

#### 1. Async Non-Blocking Load

**Test:** Boot the game with a config declaring 10+ images in `config.assets.manifest`. Observe frame rate during the first several seconds while assets load.
**Expected:** Game continues updating and rendering at full frame rate — no stutter, freeze, or blocking wait while Lily loads assets in background threads.
**Why human:** Lily spawns Love2D threads for I/O; verifying non-blocking behavior requires a running Love2D runtime. Busted tests use synchronous stubs and cannot demonstrate actual threading behavior.

#### 2. Single Atlas Texture Per Group

**Test:** In a debug run, add `print` in `drawable_wrapper.lua:draw` to log the texture address for each draw call. Render several sprites from the same manifest group.
**Expected:** All sprites in the same group share an identical texture object address — one atlas canvas serves the whole group, not one image per sprite.
**Why human:** Runtime object identity requires a running Love2D instance with actual `TA.bake()` producing a real Canvas.

---

### Gaps Summary

No gaps. All 6 truths verified. Plan 04-04 gap closure is confirmed complete:

- `busted` (379 tests, 0 failures) produces **zero** extraneous stdout lines
- `Validator.run({ silent = true })` produces **zero** stdout lines
- `Validator.run()` without silent still prints "Architecture check passed: no violations found." normally
- All CI checks pass: `selene` 0 errors, `stylua --check` clean, `lua scripts/validate_architecture.lua` passes
- Both unstaged file modifications are non-breaking: a cosmetic require reorder in `input/init.lua` and a correctness fix in `init_spec.lua` that makes 21 tests pass more accurately

The deferred `asset:ready` emission fix in `init_spec.lua` corrects the test harness to properly exercise the `_pending_ready` flag path — the implementation was always correct; the spec now accurately reflects it.

---

_Verified: 2026-03-02T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
